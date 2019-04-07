# Errors

Note that HTTP calls will almost always return `200`, even if the result is an error. One exception to this is if an internal server error occurs - in this case it will return `500`

When an error occurs, `success` will be set to `false` and `data` will contain more information about the error

```json
{
  "version": "1",
  "success": false,
  "data": {
    "code": "account:not_found",
    "description": "Account not found"
  }
}
```

# Error codes description

Code | Description
---- | -----------  
server:internal_server_error | Something went wrong on the server. Try again soon.
operation:bad_request | Parameters required by this operation are missing or incorrect. More information about error in response object `data/messages` property.
operation:not_found | Operation cannot be found. Check request URL.
operation:invalid_content | Content type of application/json header is required for all requests.
challenge:exit_not_found | The challenge of particular exit is impossible because exit is inactive or missing
challenge:utxo_not_spent | The challenge of particular exit is impossible because provided utxo is not spent
exit:invalid | Utxo was spent or does not exist.
get_status:econnrefused | Cannot connect to the Ethereum node.
in_flight_exit:tx_for_input_not_found | No transaction that created input.
transaction:not_found | Transaction doesn't exist for provided search criteria
transaction.create:insufficient_funds | Account balance is too low to satisfy the payment.
transaction.create:too_many_outputs | Total number of payments + change + fees exceed maximum allowed outputs in transaction. We need to reserve one output per payment and one output per change for each currency used in the transaction.
transaction.create:empty_transaction | Requested payment resulted in empty transaction that transfers no funds.

Refer to `...web/controllers/fallback.ex` family of files for a comprehensive list of error codes and descriptions.
