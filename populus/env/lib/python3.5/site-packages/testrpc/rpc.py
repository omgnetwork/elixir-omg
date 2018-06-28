import sys
import logging

import rlp

try:
    from sha3 import keccak_256
except ImportError:
    from sha3 import sha3_256 as keccak_256

from ethereum import blocks
from ethereum.tester import (
    languages,
)

from .client import EthTesterClient
from .client.utils import (
    force_bytes,
    decode_hex,
    encode_number,
    encode_32bytes,
)

from .utils import (
    input_transaction_formatter,
    input_filter_params_formatter,
    normalize_block_number,
)


logger = logging.getLogger(__name__)


class RPCMethods(object):
    def __init__(self):
        self.full_reset()

    def full_reset(self):
        self.client = EthTesterClient()
        self.reset_rpc_meta()

    def reset_rpc_meta(self):
        self.RPC_META = {
            'eth_protocolVersion': 63,
            'eth_syncing': False,
            'eth_mining': False,
            'net_version': 1,
            'net_listening': False,
            'net_peerCount': 0,
            'homestead_block_number': self.client.evm.block.config['HOMESTEAD_FORK_BLKNUM'],
            'dao_fork_block_number': self.client.evm.block.config['DAO_FORK_BLKNUM'],
            'anti_dos_fork_block_number': self.client.evm.block.config['ANTI_DOS_FORK_BLKNUM'],
            'clearing_fork_block_number': self.client.evm.block.config['CLEARING_FORK_BLKNUM'],
        }

    def rpc_configure(self, key, value):
        self.RPC_META[key] = value

        if key == 'homestead_block_number':
            self.client.evm.block.config['HOMESTEAD_FORK_BLKNUM'] = value
        elif key == 'dao_fork_block_number':
            self.client.evm.block.config['DAO_FORK_BLKNUM'] = value
        elif key == 'anti_dos_fork_block_number':
            self.client.evm.block.config['ANTI_DOS_FORK_BLKNUM'] = value
        elif key == 'clearing_fork_block_number':
            self.client.evm.block.config['CLEARING_FORK_BLKNUM'] = value

    #
    # Snapshot and Reset
    #
    def evm_reset(self):
        self.client.reset_evm()
        return True

    def evm_snapshot(self):
        snapshot_idx = self.client.snapshot_evm()
        return encode_number(snapshot_idx)

    def evm_revert(self, snapshot_idx=None):
        try:
            self.client.revert_evm(snapshot_idx)
        except ValueError:
            return False
        else:
            return True

    def evm_mine(self, num_blocks=1):
        for _ in range(num_blocks):
            self.client.mine_block()

    #
    #  Timetravel
    #
    def testing_timeTravel(self, timestamp):
        if timestamp <= self.client.evm.block.timestamp:
            raise ValueError(
                "Cannot travel back in time.  You'll disrupt the space time "
                "continuum"
            )
        self.client.evm.block.finalize()
        self.client.evm.block.commit_state()
        self.client.evm.db.put(
            self.client.evm.block.hash,
            rlp.encode(self.client.evm.block),
        )

        block = blocks.Block.init_from_parent(
            self.client.evm.block,
            decode_hex(self.eth_coinbase()),
            timestamp=timestamp,
        )

        self.client.evm.block = block
        self.client.evm.blocks.append(block)
        return timestamp

    #
    #  eth_ Functions
    #
    def eth_coinbase(self):
        logger.info('eth_coinbase')
        return self.client.get_coinbase()

    def eth_gasPrice(self):
        logger.info('eth_gasPrice')
        return encode_number(self.client.get_gas_price())

    def eth_blockNumber(self):
        logger.info('eth_blockNumber')
        return encode_number(self.client.get_block_number())

    def eth_sendTransaction(self, transaction):
        formatted_transaction = input_transaction_formatter(transaction)
        return self.client.send_transaction(**formatted_transaction)

    def eth_estimateGas(self, transaction, block_number="latest"):
        formatted_transaction = input_transaction_formatter(transaction)
        return self.client.estimate_gas(**formatted_transaction)

    def eth_sendRawTransaction(self, raw_tx):
        return self.client.send_raw_transaction(raw_tx)

    def eth_call(self, transaction, block_number="latest"):
        formatted_transaction = input_transaction_formatter(transaction)
        return self.client.call(**formatted_transaction)

    def eth_accounts(self):
        return self.client.get_accounts()

    def eth_getCompilers(self):
        return languages.keys()

    def eth_compileSolidity(self, code):
        # TODO: convert to python-solidity lib once it exists
        raise NotImplementedError("This has not yet been implemented")

    def eth_getCode(self, address, block_number="latest"):
        return self.client.get_code(address, normalize_block_number(block_number))

    def eth_getBalance(self, address, block_number="latest"):
        return self.client.get_balance(address, normalize_block_number(block_number))

    def eth_getTransactionCount(self, address, block_number="latest"):
        return encode_number(self.client.get_transaction_count(
            address,
            normalize_block_number(block_number),
        ))

    def eth_getTransactionByHash(self, tx_hash):
        try:
            return self.client.get_transaction_by_hash(tx_hash)
        except ValueError:
            return None

    def eth_getBlockByHash(self, block_hash, full_tx=True):
        return self.client.get_block_by_hash(block_hash, full_tx)

    def eth_getBlockByNumber(self, block_number, full_tx=True):
        return self.client.get_block_by_number(normalize_block_number(block_number), full_tx)

    def eth_getTransactionReceipt(self, tx_hash):
        try:
            return self.client.get_transaction_receipt(tx_hash)
        except ValueError:
            return None

    def eth_newBlockFilter(self, *args, **kwargs):
        # TODO: convert to tester_client once filters implemented
        raise NotImplementedError("This has not yet been implemented")

    def eth_newPendingTransactionFilter(self, *args, **kwargs):
        # TODO: convert to tester_client once filters implemented
        raise NotImplementedError("This has not yet been implemented")

    def eth_newFilter(self, filter_params):
        formatted_filter_params = input_filter_params_formatter(filter_params)
        return self.client.new_filter(**formatted_filter_params)

    def eth_getFilterChanges(self, filter_id):
        return self.client.get_filter_changes(filter_id)

    def eth_getFilterLogs(self, filter_id):
        return self.client.get_filter_logs(filter_id)

    def eth_uninstallFilter(self, filter_id):
        return self.client.uninstall_filter(filter_id)

    def eth_protocolVersion(self):
        return self.RPC_META['eth_protocolVersion']

    def eth_syncing(self):
        return self.RPC_META['eth_syncing']

    def eth_mining(self):
        return self.RPC_META['eth_mining']

    def web3_sha3(self, value, encoding='hex'):
        logger.info('web3_sha3')
        if encoding == 'hex':
            value = decode_hex(value)
        else:
            value = force_bytes(value)
        return encode_32bytes(keccak_256(value).digest())

    @classmethod
    def web3_clientVersion(cls):
        from testrpc import __version__
        return "TestRPC/" + __version__ + "/{platform}/python{v.major}.{v.minor}.{v.micro}".format(
            v=sys.version_info,
            platform=sys.platform,
        )

    #
    # net_ API
    #
    def net_version(self):
        return self.RPC_META['net_version']

    def net_listening(self):
        return self.RPC_META['net_listening']

    def net_peerCount(self):
        return self.RPC_META['net_peerCount']

    #
    # personal_ API
    #
    def personal_listAccounts(self):
        return self.eth_accounts()

    def personal_importRawKey(self, private_key, passphrase):
        return self.client.import_raw_key(private_key, passphrase)

    def personal_lockAccount(self, address):
        return self.client.lock_account(address)

    def personal_newAccount(self, passphrase=None):
        return self.client.new_account(passphrase)

    def personal_unlockAccount(self, address, passphrase, duration=None):
        return self.client.unlock_account(address, passphrase, duration)

    def personal_signAndSendTransaction(self, transaction, passphrase):
        formatted_transaction = input_transaction_formatter(transaction)
        return self.client.send_and_sign_transaction(passphrase, **formatted_transaction)
