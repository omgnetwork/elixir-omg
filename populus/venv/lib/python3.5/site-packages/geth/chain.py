import os
import json
import sys


from .wrapper import spawn_geth
from .utils.encoding import (
    force_obj_to_text,
)
from .utils.filesystem import (
    ensure_path_exists,
    is_same_path,
)


def get_live_data_dir():
    """
    pygeth needs a base directory to store it's chain data.  By default this is
    the directory that `geth` uses as it's `datadir`.
    """
    if sys.platform == 'darwin':
        data_dir = os.path.expanduser(os.path.join(
            "~",
            "Library",
            "Ethereum",
        ))
    elif sys.platform in {'linux', 'linux2', 'linux3'}:
        data_dir = os.path.expanduser(os.path.join(
            "~",
            ".ethereum",
        ))
    elif sys.platform == 'win32':
        data_dir = os.path.expanduser(os.path.join(
            "\\",
            "~",
            "AppData",
            "Roaming",
            "Ethereum",
        ))

    else:
        raise ValueError((
            "Unsupported platform: '{0}'.  Only darwin/linux2/win32 are "
            "supported.  You must specify the geth datadir manually"
        ).format(sys.platform))
    return data_dir


def get_ropsten_data_dir():
    return os.path.abspath(os.path.expanduser(os.path.join(
        get_live_data_dir(),
        "ropsten",
    )))


def get_default_base_dir():
    return get_live_data_dir()


def get_chain_data_dir(base_dir, name):
    data_dir = os.path.abspath(os.path.join(base_dir, name))
    ensure_path_exists(data_dir)
    return data_dir


def get_genesis_file_path(data_dir):
    return os.path.join(data_dir, 'genesis.json')


def is_live_chain(data_dir):
    return is_same_path(data_dir, get_live_data_dir())


def is_ropsten_chain(data_dir):
    return is_same_path(data_dir, get_ropsten_data_dir())


def write_genesis_file(genesis_file_path,
                       overwrite=False,
                       nonce="0xdeadbeefdeadbeef",
                       timestamp="0x0",
                       parentHash="0x0000000000000000000000000000000000000000000000000000000000000000",  # NOQA
                       extraData="0x686f727365",
                       gasLimit="0x47d5cc",
                       difficulty="0x01",
                       mixhash="0x0000000000000000000000000000000000000000000000000000000000000000",  # NOQA
                       coinbase="0x3333333333333333333333333333333333333333",
                       alloc=None,
                       config=None):

    if os.path.exists(genesis_file_path) and not overwrite:
        raise ValueError("Genesis file already present.  call with `overwrite=True` to overwrite this file")  # NOQA

    if alloc is None:
        alloc = {}

    if config is None:
        config = {
            'homesteadBlock': 0,
            'daoForkBlock': 0,
            'daoForSupport': True,
        }

    genesis_data = {
        "nonce": nonce,
        "timestamp": timestamp,
        "parentHash": parentHash,
        "extraData": extraData,
        "gasLimit": gasLimit,
        "difficulty": difficulty,
        "mixhash": mixhash,
        "coinbase": coinbase,
        "alloc": alloc,
        "config": config,
    }

    with open(genesis_file_path, 'w') as genesis_file:
        genesis_file.write(json.dumps(force_obj_to_text(genesis_data)))


def initialize_chain(genesis_data, data_dir, **geth_kwargs):
    genesis_file_path = get_genesis_file_path(data_dir)
    write_genesis_file(
        genesis_file_path,
        **genesis_data
    )
    command, proc = spawn_geth(dict(
        data_dir=data_dir,
        suffix_args=['init', genesis_file_path],
        **geth_kwargs
    ))
    stdoutdata, stderrdata = proc.communicate()

    if proc.returncode:
        raise ValueError("Error: {0}".format(stdoutdata + stderrdata))
