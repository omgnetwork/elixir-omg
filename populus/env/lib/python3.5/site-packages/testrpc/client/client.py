"""
Large portions of this implementation were influenced or downright copied from
the `eth-testrpc` project by ConsenSys

https://github.com/ConsenSys/eth-testrpc
"""
import os
import time
import itertools
import functools

from testrpc.compat import threading

import rlp

from ethereum import transactions
from ethereum import tester as t
from ethereum import config
from ethereum.utils import (
    privtoaddr,
)

from .utils import (
    is_string,
    coerce_args_to_bytes,
    strip_0x,
    encode_32bytes,
    encode_address,
    encode_data,
    normalize_number,
    normalize_address,
    decode_hex,
    mk_random_privkey,
    is_array,
    normalize_block_identifier)
from .serializers import (
    serialize_txn,
    serialize_txn_receipt,
    serialize_block,
)
from .filters import (
    check_filter_topics_validity,
    process_block,
    get_filter_bounds,
)


# Set the gas
DEFAULT_GAS_LIMIT = t.gas_limit = t.GAS_LIMIT = int(os.environ.get('TESTRPC_GAS_LIMIT', 4000000))
config.default_config['GENESIS_GAS_LIMIT'] = DEFAULT_GAS_LIMIT


def with_lock(client_method):
    @functools.wraps(client_method)
    def inner(self, *args, **kwargs):
        self._evm_lock.acquire()
        try:
            return client_method(self, *args, **kwargs)
        finally:
            self._evm_lock.release()

    return inner


class EthTesterClient(object):
    """
    Stand-in replacement for the rpc client that speaks directly to the
    `ethereum.tester` facilities.
    """
    locked_accounts = None
    homestead_block_number = 0
    dao_fork_block_number = 0
    anti_dos_fork_block_number = 0
    clearing_fork_block_number = 0
    dao_fork_support = True

    def __init__(self):
        self._evm_lock = threading.Lock()

        self.snapshots = []

        self.reset_evm()

        self.evm.block.config['HOMESTEAD_FORK_BLKNUM'] = self.homestead_block_number  # noqa
        self.evm.block.config['DAO_FORK_BLKNUM'] = self.dao_fork_block_number
        self.evm.block.config['ANTI_DOS_FORK_BLKNUM'] = self.anti_dos_fork_block_number
        self.evm.block.config['CLEARING_FORK_BLKNUM'] = self.clearing_fork_block_number

        self.passphrase_accounts = {}
        self.passphrase_account_keys = {}
        self.unlocked_accounts = {}

        self.log_filters = {}
        self.log_filters_id_generator = itertools.count()

    @with_lock
    def reset_evm(self, snapshot_idx=None):
        if snapshot_idx is not None:
            self.revert_evm(snapshot_idx)
        else:
            self.evm = t.state()
            self.evm.block.gas_limit = DEFAULT_GAS_LIMIT

    @with_lock
    def snapshot_evm(self):
        self.snapshots.append((self.evm.block.number, self.evm.snapshot()))
        return len(self.snapshots) - 1

    @with_lock
    def revert_evm(self, snapshot_idx=None, reset_logs=False):
        if len(self.snapshots) == 0:
            raise ValueError("No snapshots to revert to")

        if snapshot_idx is not None:
            block_number, snapshot = self.snapshots.pop(snapshot_idx)
        else:
            block_number, snapshot = self.snapshots.pop()

        # Remove all blocks after our saved block number.
        del self.evm.blocks[block_number:]

        self.evm.revert(snapshot)
        self.evm.blocks.append(self.evm.block)

    @with_lock
    def mine_block(self):
        self.evm.mine()

    def wait_for_block(self, block_number, max_wait=0):
        while self.get_block_number() < block_number:
            self.mine_block()
        return self.get_block_by_number(self.get_block_number())

    def wait_for_transaction(self, txn_hash, max_wait=0):
        return self.get_transaction_receipt(txn_hash)

    def get_max_gas(self):
        return t.gas_limit

    #
    # Internal getters for EVM objects
    #
    def _get_transaction_by_hash(self, txn_hash):
        txn_hash = strip_0x(txn_hash)
        if len(txn_hash) == 64:
            txn_hash = decode_hex(txn_hash)
        for block in reversed(self.evm.blocks):
            txn_hashes = block.get_transaction_hashes()

            if txn_hash in txn_hashes:
                txn_index = txn_hashes.index(txn_hash)
                txn = block.transaction_list[txn_index]
                break
        else:
            raise ValueError("Transaction not found")
        return block, txn, txn_index

    def _get_block_by_number(self, block_number="latest"):
        if block_number == "latest":
            if not self.evm.blocks:
                raise ValueError("No blocks")
            elif len(self.evm.blocks) > 1:
                return self.evm.blocks[-2]
            else:
                return self.evm.blocks[-1]
        elif block_number == "earliest":
            return self.evm.blocks[0]
        elif block_number == "pending":
            return self.evm.block
        else:
            block_number = normalize_number(block_number)

            if block_number >= len(self.evm.blocks):
                raise ValueError("Invalid block number")
            return self.evm.blocks[block_number]

    def _get_block_by_hash(self, block_hash):
        if len(block_hash) > 32:
            block_hash = decode_hex(strip_0x(block_hash))
        for block in self.evm.blocks:
            if block.hash == block_hash:
                return block
        else:
            raise ValueError("Could not find block for provided hash")

    @with_lock
    @coerce_args_to_bytes
    def _send_transaction(self, _from=None, to=None, gas=None, gas_price=None,
                          value=0, data=b''):
        """
        The tester doesn't care about gas so we discard it.
        """
        if _from is None:
            _from = self.get_coinbase()

        _from = normalize_address(_from)

        try:
            sender = t.keys[t.accounts.index(_from)]
        except ValueError:
            if _from in self.unlocked_accounts:
                unlock_expiration = self.unlocked_accounts[_from]
                if unlock_expiration is None or unlock_expiration > time.time():
                    sender = self.passphrase_account_keys[_from]
                else:
                    raise ValueError("Account locked.  Unlock before sending tx")
            else:
                raise

        if to is None:
            to = b''

        to = normalize_address(to, allow_blank=True)

        if data is None:
            data = b''

        data = decode_hex(data)

        try:
            if gas is not None:
                t.gas_limit = gas
            if gas_price is not None:
                t.gas_price = gas_price
            output = self.evm.send(sender=sender, to=to, value=value, evmdata=data)
        finally:
            t.gas_limit = t.GAS_LIMIT
            t.gas_price = t.GAS_PRICE

        return output

    #
    # Public API
    #
    def get_coinbase(self):
        return encode_address(self.evm.block.coinbase)

    def get_accounts(self):
        return [
            encode_address(addr) for addr in t.accounts
        ] + [
            encode_address(addr) for addr in self.passphrase_accounts.keys()
        ]

    def get_code(self, address, block_number="latest"):
        block = self._get_block_by_number(block_number)
        return encode_data(block.get_code(strip_0x(address)))

    def estimate_gas(self, *args, **kwargs):
        snapshot_idx = self.snapshot_evm()

        try:
            txn_hash = self.send_transaction(*args, **kwargs)
            txn_receipt = self.get_transaction_receipt(txn_hash)
            gas_used = txn_receipt['gasUsed']
        finally:
            self.revert_evm(snapshot_idx)

        return gas_used

    def send_transaction(self, *args, **kwargs):
        try:
            self._send_transaction(*args, **kwargs)
        finally:
            self.mine_block()
        return encode_32bytes(self.evm.last_tx.hash)

    def send_raw_transaction(self, raw_tx):
        tx = rlp.decode(decode_hex(strip_0x(raw_tx)), transactions.Transaction)

        to = encode_address(tx.to) if tx.to else b''
        _from = encode_address(tx.sender)
        data = encode_data(tx.data)

        return self.send_transaction(
            _from=_from,
            to=to,
            gas_price=tx.gasprice,
            gas=tx.startgas,
            value=tx.value,
            data=data,
        )

    def get_transaction_receipt(self, txn_hash):
        block, txn, txn_index = self._get_transaction_by_hash(txn_hash)

        return serialize_txn_receipt(block, txn, txn_index)

    def get_transaction_count(self, address, block_number="latest"):
        block = self._get_block_by_number(block_number)
        address = normalize_address(address)

        return block.get_nonce(address)

    def get_block_by_number(self, block_number, full_transactions=True):
        block = self._get_block_by_number(block_number)

        return serialize_block(block, full_transactions)

    def get_block_by_hash(self, block_hash, full_transactions=True):
        block = self._get_block_by_hash(block_hash)

        return serialize_block(block, full_transactions)

    def get_block_number(self):
        if len(self.evm.blocks) < 2:
            return 0
        else:
            return self.evm.blocks[-2].number

    def get_gas_price(self):
        return t.gas_price

    def get_balance(self, address, block="latest"):
        _block = self._get_block_by_number(block)
        return _block.get_balance(strip_0x(address))

    def call(self, *args, **kwargs):
        if len(args) >= 7 and args[6] != "latest":
            raise ValueError("Using call on any block other than latest is unsupported")
        if kwargs.get('block', 'latest') != "latest":
            raise ValueError("Using call on any block other than latest is unsupported")
        snapshot_idx = self.snapshot_evm()
        output = self._send_transaction(*args, **kwargs)
        self.revert_evm(snapshot_idx)

        return encode_data(output)

    def get_transaction_by_hash(self, txn_hash):
        block, txn, txn_index = self._get_transaction_by_hash(txn_hash)
        return serialize_txn(block, txn, txn_index)

    def lock_account(self, address):
        address = normalize_address(address)
        self.unlocked_accounts.pop(address, None)
        return True

    @coerce_args_to_bytes
    def check_passphrase(self, address, passphrase):
        address = normalize_address(address)
        if address not in self.passphrase_accounts:
            return False
        elif passphrase == self.passphrase_accounts[address]:
            return True
        else:
            return False

    @coerce_args_to_bytes
    def unlock_account(self, address, passphrase, duration=None):
        address = normalize_address(address)
        if self.check_passphrase(address, passphrase):
            if duration is not None:
                unlock_expiration = time.time() + duration
            else:
                unlock_expiration = None
            self.unlocked_accounts[address] = unlock_expiration
            return True
        return False

    @coerce_args_to_bytes
    def import_raw_key(self, private_key, passphrase):
        if not passphrase:
            raise ValueError("Cannot have empty passphrase")

        public_key = privtoaddr(private_key)

        self.passphrase_accounts[public_key] = passphrase
        self.passphrase_account_keys[public_key] = private_key

        return encode_address(public_key)

    @coerce_args_to_bytes
    def new_account(self, passphrase):
        private_key = mk_random_privkey()

        return self.import_raw_key(private_key, passphrase)

    @coerce_args_to_bytes
    def send_and_sign_transaction(self, passphrase, **txn_kwargs):
        try:
            _from = txn_kwargs['_from']
        except KeyError:
            raise KeyError("`send_and_sign_transaction` requires a `_from` address to be specified")  # NOQa

        _from = normalize_address(_from)

        try:
            self.unlock_account(_from, passphrase)
            return self.send_transaction(**txn_kwargs)
        finally:
            self.lock_account(_from)

    log_filters = None

    def new_filter(self, from_block=None, to_block=None, address=None, topics=None):
        if topics is None:
            topics = []

        if address is None:
            address = []

        try:
            from_block = normalize_block_identifier(from_block)
        except ValueError:
            raise ValueError("Invalid filter parameter for `from_block`")

        try:
            to_block = normalize_block_identifier(to_block)
        except ValueError:
            raise ValueError("Invalid filter parameter for `to_block`")

        if is_string(address):
            addresses = [encode_32bytes(normalize_address(address))]
        elif is_array(address):
            if not address:
                addresses = []
            elif all(is_string(addr) for addr in address):
                addresses = [encode_32bytes(normalize_address(addr)) for addr in address]
            else:
                raise ValueError(
                    "Address must be either a single address or an array of addresses"
                )
        else:
            raise ValueError(
                "Address must be either a single address or an array of addresses"
            )

        if not check_filter_topics_validity(topics):
            raise ValueError("Invalid topics")

        log_filter = {
            'from_block': from_block,
            'to_block': to_block,
            'addresses': addresses,
            'topics': topics,
        }
        filter_id = next(self.log_filters_id_generator)
        self.log_filters[filter_id] = log_filter
        return filter_id

    def new_block_filter(self, *args, **kwargs):
        raise NotImplementedError("TODO")

    def new_pending_transaction_filter(self, *args, **kwargs):
        raise NotImplementedError("TODO")

    def uninstall_filter(self, filter_id):
        try:
            self.log_filters.pop(filter_id)
        except KeyError:
            return False
        else:
            return True

    def get_filter_changes(self, filter_id):
        try:
            log_filter = self.log_filters[filter_id]
        except KeyError:
            raise ValueError("Filter not found for id: {0}".format(filter_id))

        bookmark = log_filter.get('bookmark', None)
        block_slice = get_filter_bounds(
            log_filter['from_block'],
            log_filter['to_block'],
            bookmark,
        )

        block_processor_fn = functools.partial(
            process_block,
            from_block=log_filter['from_block'],
            to_block=log_filter['to_block'],
            addresses=log_filter['addresses'],
            filter_topics=log_filter['topics'],
        )

        log_changes = list(itertools.chain.from_iterable((
            block_processor_fn(block) for block in self.evm.blocks[block_slice]
        )))

        self.log_filters[filter_id]['bookmark'] = self.evm.blocks[-1].number
        return log_changes

    def get_filter_logs(self, filter_id):
        try:
            log_filter = self.log_filters[filter_id]
        except KeyError:
            raise ValueError("Filter not found for id: {0}".format(filter_id))

        block_slice = get_filter_bounds(
            log_filter['from_block'],
            log_filter['to_block'],
        )

        block_processor_fn = functools.partial(
            process_block,
            from_block=log_filter['from_block'],
            to_block=log_filter['to_block'],
            addresses=log_filter['addresses'],
            filter_topics=log_filter['topics'],
        )

        all_log_entries = list(itertools.chain.from_iterable((
            block_processor_fn(block) for block in self.evm.blocks[block_slice]
        )))

        return all_log_entries
