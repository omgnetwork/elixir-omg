import json
import functools

from werkzeug.wrappers import Request, Response

from jsonrpc import JSONRPCResponseManager, dispatcher

from .rpc import RPCMethods
from .compat import threading
from .client.utils import (
    force_obj_to_text,
)


RESPONSE_HEADERS = {
    "Access-Control-Allow-Headers": "Origin, X-Requested-With, Content-Type, Accept",
    "Access-Control-Allow-Origin": "*",
}


def get_application():
    # When calling server.register_function, first wrap the function in a mutex.
    # This has the effect of serializing all RPC calls. Although we use a
    # multithreaded HTTP server, the EVM itself is not thread-safe, so we must take
    # care when interacting with it.
    rpc_methods = RPCMethods()
    evm_lock = threading.Lock()

    def with_lock(rpc_fn):
        @functools.wraps(rpc_fn)
        def inner(*args, **kwargs):
            evm_lock.acquire()
            try:
                return rpc_fn(*args, **kwargs)
            finally:
                evm_lock.release()

        return inner

    def add_method_with_lock(rpc_fn, *args, **kwargs):
        rpc_fn_with_lock = with_lock(rpc_fn)
        return dispatcher.add_method(rpc_fn_with_lock, *args, **kwargs)

    add_method_with_lock(rpc_methods.eth_coinbase, 'eth_coinbase')
    add_method_with_lock(rpc_methods.eth_accounts, 'eth_accounts')
    add_method_with_lock(rpc_methods.eth_gasPrice, 'eth_gasPrice')
    add_method_with_lock(rpc_methods.eth_blockNumber, 'eth_blockNumber')
    add_method_with_lock(rpc_methods.eth_estimateGas, 'eth_estimateGas')
    add_method_with_lock(rpc_methods.eth_call, 'eth_call')
    add_method_with_lock(rpc_methods.eth_sendTransaction, 'eth_sendTransaction')
    add_method_with_lock(rpc_methods.eth_sendRawTransaction, 'eth_sendRawTransaction')
    add_method_with_lock(rpc_methods.eth_getCompilers, 'eth_getCompilers')
    add_method_with_lock(rpc_methods.eth_compileSolidity, 'eth_compileSolidity')
    add_method_with_lock(rpc_methods.eth_getCode, 'eth_getCode')
    add_method_with_lock(rpc_methods.eth_getBalance, 'eth_getBalance')
    add_method_with_lock(rpc_methods.eth_getTransactionCount, 'eth_getTransactionCount')
    add_method_with_lock(rpc_methods.eth_getTransactionByHash, 'eth_getTransactionByHash')
    add_method_with_lock(rpc_methods.eth_getTransactionReceipt, 'eth_getTransactionReceipt')
    add_method_with_lock(rpc_methods.eth_getBlockByHash, 'eth_getBlockByHash')
    add_method_with_lock(rpc_methods.eth_getBlockByNumber, 'eth_getBlockByNumber')
    add_method_with_lock(rpc_methods.eth_newBlockFilter, 'eth_newBlockFilter')
    add_method_with_lock(rpc_methods.eth_newPendingTransactionFilter,
                         'eth_newPendingTransactionFilter')
    add_method_with_lock(rpc_methods.eth_newFilter, 'eth_newFilter')
    add_method_with_lock(rpc_methods.eth_getFilterChanges, 'eth_getFilterChanges')
    add_method_with_lock(rpc_methods.eth_getFilterLogs, 'eth_getFilterLogs')
    add_method_with_lock(rpc_methods.eth_uninstallFilter, 'eth_uninstallFilter')
    add_method_with_lock(rpc_methods.eth_protocolVersion, 'eth_protocolVersion')
    add_method_with_lock(rpc_methods.eth_syncing, 'eth_syncing')
    add_method_with_lock(rpc_methods.eth_mining, 'eth_mining')
    add_method_with_lock(rpc_methods.web3_sha3, 'web3_sha3')
    add_method_with_lock(rpc_methods.web3_clientVersion, 'web3_clientVersion')
    add_method_with_lock(rpc_methods.net_version, 'net_version')
    add_method_with_lock(rpc_methods.net_listening, 'net_listening')
    add_method_with_lock(rpc_methods.net_peerCount, 'net_peerCount')
    add_method_with_lock(rpc_methods.evm_reset, 'evm_reset')
    add_method_with_lock(rpc_methods.evm_snapshot, 'evm_snapshot')
    add_method_with_lock(rpc_methods.evm_revert, 'evm_revert')
    add_method_with_lock(rpc_methods.evm_mine, 'evm_mine')
    add_method_with_lock(rpc_methods.rpc_configure, 'rpc_configure')
    add_method_with_lock(rpc_methods.testing_timeTravel, 'testing_timeTravel')
    add_method_with_lock(rpc_methods.personal_importRawKey, 'personal_importRawKey')
    add_method_with_lock(rpc_methods.personal_listAccounts, 'personal_listAccounts')
    add_method_with_lock(rpc_methods.personal_lockAccount, 'personal_lockAccount')
    add_method_with_lock(rpc_methods.personal_newAccount, 'personal_newAccount')
    add_method_with_lock(rpc_methods.personal_unlockAccount, 'personal_unlockAccount')
    add_method_with_lock(rpc_methods.personal_signAndSendTransaction,
                         'personal_signAndSendTransaction')

    @Request.application
    def application(request):
        response = JSONRPCResponseManager.handle(
            request.data,
            dispatcher,
        )
        response = Response(
            json.dumps(force_obj_to_text(response.data, True)),
            headers=RESPONSE_HEADERS,
            mimetype='application/json',
        )
        return response

    application.rpc_methods = rpc_methods

    return application
