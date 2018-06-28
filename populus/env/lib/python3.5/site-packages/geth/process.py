import os
import logging
import socket
import subprocess
import time
import warnings

try:
    from urllib.request import (
        urlopen,
        URLError,
    )
except ImportError:
    from urllib2 import (
        urlopen,
        URLError,
    )

from geth.utils.networking import (  # noqa: E402
    get_ipc_socket,
)
from geth.utils.dag import (  # noqa: E402
    is_dag_generated,
)
from geth.utils.proc import (  # noqa: E402
    kill_proc,
)
from geth.utils.timeout import (
    Timeout,
)
from geth.accounts import (  # noqa: E402
    ensure_account_exists,
    get_accounts,
)
from geth.wrapper import (  # noqa: E402
    construct_test_chain_kwargs,
    construct_popen_command,
)
from geth.chain import (  # noqa: E402
    get_chain_data_dir,
    get_default_base_dir,
    get_genesis_file_path,
    get_live_data_dir,
    get_ropsten_data_dir,
    initialize_chain,
    is_live_chain,
    is_ropsten_chain,
)


logger = logging.getLogger(__name__)


class BaseGethProcess(object):
    _proc = None

    def __init__(self, geth_kwargs):
        self.geth_kwargs = geth_kwargs
        self.command = construct_popen_command(**geth_kwargs)

    is_running = False

    def start(self):
        if self.is_running:
            raise ValueError("Already running")
        self.is_running = True

        logger.info("Launching geth: %s", " ".join(self.command))
        self.proc = subprocess.Popen(
            self.command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def __enter__(self):
        self.start()
        return self

    def stop(self):
        if not self.is_running:
            raise ValueError("Not running")

        if self.proc.poll() is None:
            kill_proc(self.proc)

        self.is_running = False

    def __exit__(self, *exc_info):
        self.stop()

    @property
    def is_alive(self):
        return self.is_running and self.proc.poll() is None

    @property
    def is_stopped(self):
        return self.proc is not None and self.proc.poll() is not None

    @property
    def accounts(self):
        return get_accounts(**self.geth_kwargs)

    @property
    def rpc_enabled(self):
        return self.geth_kwargs.get('rpc_enabled', False)

    @property
    def rpc_host(self):
        return self.geth_kwargs.get('rpc_host', '127.0.0.1')

    @property
    def rpc_port(self):
        return self.geth_kwargs.get('rpc_port', '8545')

    @property
    def is_rpc_ready(self):
        try:
            urlopen("http://{0}:{1}".format(
                self.rpc_host,
                self.rpc_port,
            ))
        except URLError:
            return False
        else:
            return True

    def wait_for_rpc(self, timeout=0):
        if not self.rpc_enabled:
            raise ValueError("RPC interface is not enabled")

        with Timeout(timeout) as _timeout:
            while True:
                if self.is_rpc_ready:
                    break
                time.sleep(0.1)
                _timeout.check()

    @property
    def ipc_enabled(self):
        return not self.geth_kwargs.get('ipc_disable', None)

    @property
    def ipc_path(self):
        return self.geth_kwargs.get(
            'ipc_path',
            os.path.abspath(os.path.expanduser(os.path.join(
                self.data_dir, 'geth.ipc',
            )))
        )

    @property
    def is_ipc_ready(self):
        try:
            with get_ipc_socket(self.ipc_path):
                pass
        except socket.error:
            return False
        else:
            return True

    def wait_for_ipc(self, timeout=0):
        if not self.ipc_enabled:
            raise ValueError("IPC interface is not enabled")

        with Timeout(timeout) as _timeout:
            while True:
                if self.is_ipc_ready:
                    break
                time.sleep(0.1)
                _timeout.check()

    @property
    def is_dag_generated(self):
        return is_dag_generated()

    @property
    def is_mining(self):
        return self.geth_kwargs.get('mine', False)

    def wait_for_dag(self, timeout=0):
        if not self.is_mining and not self.geth_kwargs.get('autodag', False):
            raise ValueError("Geth not configured to generate DAG")

        with Timeout(timeout) as _timeout:
            while True:
                if self.is_dag_generated:
                    break
                time.sleep(0.1)
                _timeout.check()


class MainnetGethProcess(BaseGethProcess):
    def __init__(self, geth_kwargs=None):
        if geth_kwargs is None:
            geth_kwargs = {}

        if 'data_dir' in geth_kwargs:
            raise ValueError("You cannot specify `data_dir` for a MainnetGethProcess")

        super(MainnetGethProcess, self).__init__(geth_kwargs)

    @property
    def data_dir(self):
        return get_live_data_dir()


class LiveGethProcess(MainnetGethProcess):
    def __init__(self, *args, **kwargs):
        warnings.warn(DeprecationWarning(
            "The `LiveGethProcess` has been renamed to `MainnetGethProcess`. "
            "The `LiveGethProcess` alias will be removed in subsequent releases"
        ))
        super(LiveGethProcess, self).__init__(*args, **kwargs)


class RopstenGethProcess(BaseGethProcess):
    def __init__(self, geth_kwargs=None):
        if geth_kwargs is None:
            geth_kwargs = {}

        if 'data_dir' in geth_kwargs:
            raise ValueError(
                "You cannot specify `data_dir` for a {0}".format(type(self).__name__)
            )
        if 'network_id' in geth_kwargs:
            raise ValueError(
                "You cannot specify `network_id` for a {0}".format(type(self).__name__)
            )

        geth_kwargs['network_id'] = '3'
        geth_kwargs['data_dir'] = get_ropsten_data_dir()

        super(RopstenGethProcess, self).__init__(geth_kwargs)

    @property
    def data_dir(self):
        return get_ropsten_data_dir()


class TestnetGethProcess(RopstenGethProcess):
    """
    Alias for whatever the current primary testnet chain is.
    """
    pass


class DevGethProcess(BaseGethProcess):
    """
    A local private chain for development.
    """
    def __init__(self, chain_name, base_dir=None, overrides=None, genesis_data=None):
        if overrides is None:
            overrides = {}

        if genesis_data is None:
            genesis_data = {}

        if 'data_dir' in overrides:
            raise ValueError("You cannot specify `data_dir` for a DevGethProcess")

        if base_dir is None:
            base_dir = get_default_base_dir()

        self.data_dir = get_chain_data_dir(base_dir, chain_name)
        geth_kwargs = construct_test_chain_kwargs(
            data_dir=self.data_dir,
            **overrides
        )

        # ensure that an account is present
        coinbase = ensure_account_exists(**geth_kwargs)

        # ensure that the chain is initialized
        genesis_file_path = get_genesis_file_path(self.data_dir)

        needs_init = all((
            not os.path.exists(genesis_file_path),
            not is_live_chain(self.data_dir),
            not is_ropsten_chain(self.data_dir),
        ))

        if needs_init:
            genesis_data.setdefault(
                'alloc',
                dict([
                    (coinbase, {"balance": "1000000000000000000000000000000"}),  # 1 billion ether.
                ])
            )
            initialize_chain(genesis_data, **geth_kwargs)

        super(DevGethProcess, self).__init__(geth_kwargs)
