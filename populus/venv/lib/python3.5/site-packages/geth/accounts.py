import os
import re

from .wrapper import spawn_geth
from .utils.proc import format_error_message


def get_accounts(data_dir, **geth_kwargs):
    """
    Returns all geth accounts as tuple of hex encoded strings

    >>> geth_accounts()
    ... ('0x...', '0x...')
    """
    command, proc = spawn_geth(dict(
        data_dir=data_dir,
        suffix_args=['account', 'list'],
        **geth_kwargs
    ))
    stdoutdata, stderrdata = proc.communicate()

    if proc.returncode:
        if "no keys in store" in stderrdata.decode("utf-8"):
            return tuple()
        else:
            raise ValueError(format_error_message(
                "Error trying to list accounts",
                command,
                proc.returncode,
                stdoutdata,
                stderrdata,
            ))
    accounts = parse_geth_accounts(stdoutdata)
    return accounts


account_regex = re.compile(b'\{([a-f0-9]{40})\}')


def create_new_account(data_dir, password, **geth_kwargs):
    """Creates a new Ethereum account on geth.

    This is useful for testing when you want to stress
    interaction (transfers) between Ethereum accounts.

    This command communicates with ``geth`` command over
    terminal interaction. It creates keystore folder and new
    account there.

    This function only works against offline geth processes,
    because geth builds an account cache when starting up.
    If geth process is already running you can create new
    accounts using
    `web3.personal.newAccount()
    <https://github.com/ethereum/go-ethereum/wiki/JavaScript-Console#personalnewaccount>_`
    RPC API.


    Example py.test fixture for tests:

    .. code-block:: python

        import os

        from geth.wrapper import DEFAULT_PASSWORD_PATH
        from geth.accounts import create_new_account


        @pytest.fixture
        def target_account() -> str:
            '''Create a new Ethereum account on a running Geth node.

            The account can be used as a withdrawal target for tests.

            :return: 0x address of the account
            '''

            # We store keystore files in the current working directory
            # of the test run
            data_dir = os.getcwd()

            # Use the default password "this-is-not-a-secure-password"
            # as supplied in geth/default_blockchain_password file.
            # The supplied password must be bytes, not string,
            # as we only want ASCII characters and do not want to
            # deal encoding problems with passwords
            account = create_new_account(data_dir, DEFAULT_PASSWORD_PATH)
            return account

    :param data_dir: Geth data fir path - where to keep "keystore" folder
    :param password: Path to a file containing the password
        for newly created account
    :param geth_kwargs: Extra command line arguments passwrord to geth
    :return: Account as 0x prefixed hex string
    """
    if os.path.exists(password):
        geth_kwargs['password'] = password

    command, proc = spawn_geth(dict(
        data_dir=data_dir,
        suffix_args=['account', 'new'],
        **geth_kwargs
    ))

    if os.path.exists(password):
        stdoutdata, stderrdata = proc.communicate()
    else:
        stdoutdata, stderrdata = proc.communicate(b"\n".join((password, password)))

    if proc.returncode:
        raise ValueError(format_error_message(
            "Error trying to create a new account",
            command,
            proc.returncode,
            stdoutdata,
            stderrdata,
        ))

    match = account_regex.search(stdoutdata)
    if not match:
        raise ValueError(format_error_message(
            "Did not find an address in process output",
            command,
            proc.returncode,
            stdoutdata,
            stderrdata,
        ))

    return b'0x' + match.groups()[0]


def ensure_account_exists(data_dir, **geth_kwargs):
    accounts = get_accounts(data_dir, **geth_kwargs)
    if not accounts:
        account = create_new_account(data_dir, **geth_kwargs)
    else:
        account = accounts[0]
    return account


def parse_geth_accounts(raw_accounts_output):
    accounts = account_regex.findall(raw_accounts_output)
    return tuple(b'0x' + account for account in accounts)
