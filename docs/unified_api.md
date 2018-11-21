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

We can follow the same model and ensure consistency across all OmiseGO services.

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
          "currency": "0000000000000000000000000000000000000000",
          "amount": 100
      },
      {
          "currency": "1234560000000000000000000000000000000000",
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
## OmiseGo Plasma API
An incomplete list of endpoints to demonstrate the format:
```
/account.get_balance
/account.get_utxos
/account.get_transactions
/utxo.get_exit_data
/utxo.get_challenge_data
/transaction.get
/transaction.create
/transaction.submit
/block.get
/status
```

## Architecture
Suggestion from Robin is to have a sort of ReverseProxy app that sits in front of the other services and routes the calls to the appropriate service e.g. `/api/transaction.submit` goes to the ChildChain and `/api/account.get_utxos` goes to the Watcher.

I think this can work with HTTP calls, although I'm not sure about WebSockets...
