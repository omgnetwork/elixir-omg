# Watcher

OMG Watcher in security-critical mode

/utxo.get_exit_data
/utxo.get_challenge_data
/transaction.submit

## TEMPLATE - remove me

```shell
http POST /transaction.submit transaction=f8d083015ba98080808080940000...
```

```elixir
// TODO
```

```javascript
// TODO
```

> The above command returns JSON document:

```json
{
      "version": "1",
      "success": true,
      "data": {
          
      }
}
```

This endpoint submits signed transaction to the child chain

### HTTP Request

`POST /transaction.submit`

### JSON Body

Key | Value | Description
--------- | ------- | -----------
transaction | Hex encoded string | Signed transaction RLP-encoded to bytes and HEX-encoded to string



