import os

from .wrapper import (
    spawn_geth_subprocess,
)
from .chains import (
    is_live_chain,
    is_testnet_chain,
)
from .utils.filesystem import (
    remove_file_if_exists,
    remove_dir_if_exists,
)


def soft_reset_chain(allow_live=False, allow_testnet=False, **geth_kwargs):
    data_dir = geth_kwargs.get('data_dir')

    if data_dir is None or (not allow_live and is_live_chain(data_dir)):
        raise ValueError("To reset the live chain you must call this function with `allow_live=True`")  # NOQA

    if not allow_testnet and is_testnet_chain(data_dir):
        raise ValueError("To reset the testnet chain you must call this function with `allow_testnet=True`")  # NOQA

    suffix_args = geth_kwargs.pop('suffix_args', [])
    suffix_args.extend((
        'removedb',
    ))

    geth_kwargs['suffix_args'] = suffix_args

    _, proc = spawn_geth_subprocess(**geth_kwargs)

    stdoutdata, stderrdata = proc.communicate("y")

    if "Removing chaindata" not in stdoutdata:
        raise ValueError("An error occurred while removing the chain:\n\nError:\n{0}\n\nOutput:\n{1}".format(stderrdata, stdoutdata))  # NOQA


def hard_reset_chain(data_dir, allow_live=False, allow_testnet=False):
    if not allow_live and is_live_chain(data_dir):
        raise ValueError("To reset the live chain you must call this function with `allow_live=True`")  # NOQA

    if not allow_testnet and is_testnet_chain(data_dir):
        raise ValueError("To reset the testnet chain you must call this function with `allow_testnet=True`")  # NOQA

    blockchain_dir = os.path.join(data_dir, 'chaindata')
    remove_dir_if_exists(blockchain_dir)

    dapp_dir = os.path.join(data_dir, 'dapp')
    remove_dir_if_exists(dapp_dir)

    nodekey_path = os.path.join(data_dir, 'nodekey')
    remove_file_if_exists(nodekey_path)

    nodes_path = os.path.join(data_dir, 'nodes')
    remove_dir_if_exists(nodes_path)

    geth_ipc_path = os.path.join(data_dir, 'geth.ipc')
    remove_file_if_exists(geth_ipc_path)

    history_path = os.path.join(data_dir, 'history')
    remove_file_if_exists(history_path)
