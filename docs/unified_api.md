# Unified API

## Problem
Currently the Childchain API and Watcher API behave differently e.g.
 - Childchain API:
   - Must have jsonrpc and id in the request body
   - **Cannot** have 'Content-Type': 'application/json' header
   - On error, response contains response.error
 - Watcher API:
   - **Must** have 'Content-Type': 'application/json' header
   - On error, response contains response.result === 'error'

Also on the roadmap is the **Informational API Service** that will provide non-critical convenience APIs.

All three APIs should behave consistently.

## Proposal
The eWallet already has a well defined API, using HTTP-RPC (rather than REST).
 - [eWallet Admin API](https://ewallet.staging.omisego.io/api/admin/docs.ui)
 - [eWallet Client API](https://ewallet.staging.omisego.io/api/client/docs.ui)

We can follow the same model and ensure consistency across all OMG Network services.

#### eWallet API characteristics
The API is a collection of HTTP-RPC style method calls in the format
```
EWALLET_URL/api/METHOD_FAMILY.method
```
where `METHOD_FAMILY` is one of the functional parts of the API e.g. `account`, `transaction`, etc.

Responses contain all data, metadata or errors in the body of the response. This means that HTTP calls always return `200`, even if the result is an error. One exception to this is if an internal server error occurs - in this case it will return `500`

All HTTP calls are `POST` for consistency.

Following this HTTP-RPC style means that the service can be used via websockets as well as HTTP.

Example:
```
POST http://plasma-chain.network/api/account.get_balance
BODY
{
    "address": "0x40d6a26bd478e60f97755d62196f0d0f85c1be0d"
}

RESPONSE 200
{
  "version": "1",
  "success": true,
  "data": [
      {
          "currency": "0x0000000000000000000000000000000000000000",
          "amount": 100
      },
      {
          "currency": "0x1234560000000000000000000000000000000000",
          "amount": 300000
      }
  ]
}

RESPONSE 200
{
  "version": "1",
  "success": false,
  "data": {
    "object": "error",
    "code": "account:not_found",
    "description": "Account not found"
  }
}


RESPONSE 500
{
  "version": "1",
  "success": false,
  "data": {
    "object": "error",
    "code": "server:internal_server_error",
    "description": "Something went wrong on the server",
    "messages": {
      "error_key": "error_reason"
    }
  }
}
```
## OMG Network Plasma API
There are three services involved

### 1. ChildChain
Normally a user wouldn't call the ChildChain API directly, as doing so would lose the security features of the Watcher. However there may be some low-stake accounts that don't care or are fine with some amount of trust in the ChildChain operator. These users can call e.g. `submit` on the ChildChain directly.

#### API endpoints
```
/block.get
/transaction.submit
```

### 2. Watcher
The watcher first and foremost plays a critical security role in the system. The watcher monitors the child chain and root chain (Ethereum) for faulty activity.

#### API endpoints
```
/transaction.get
/transaction.get_in_flight_exit
/transaction.submit
/utxo.get_exit_data
/utxo.get_challenge_data
/status
```

#### Events
```
  new_block
  new_transaction
  new_deposit
  exit_started
  exit_challenged
  in_flight_exit_started
  in_flight_exit_challenged
  exit_success
  piggyback
  invalid_block
  unchallenged_exit
  block_withholding
  invalid_fee_exit
```


### 3. Informational/Convenience API
This service may end up being included in the Watcher as optional functionality, but conceptually it can be seen as a separate service. It stores informational data about the chain, and provides convenience APIs to proxy to the child chain/root chain/watcher to ease integration and reduce duplicate code in libraries.

#### API endpoints
```
/account.get_balance
/account.get_utxos
/account.get_transactions
/transaction.all
/transaction.create
/transaction.get
/transaction.get_in_flight_exit
/block.all
/block.get
... utxo management apis ...
```

#### Events
```
  transaction_confirmed
  address_received
  address_spent
```

## Architecture
To be decided...
