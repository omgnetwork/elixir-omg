# Child chain

## Submit transaction

```shell
curl http://localhost:4000/transaction.submit -d '{"transaction": "b325602686..."}'
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
          "blknum": 123000,
          "txindex": 111,
          "txhash": "bdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d"
      }
}
```

This endpoint submits a signed transaction to the child chain.

### HTTP Request

`POST /transaction.submit`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
transaction | Hex encoded string | Signed transaction RLP-encoded to bytes and HEX-encoded to string




## Get Block by id

```shell
curl http://localhost:4000/block.get -d '{"hash": "2733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f}'
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
          "blknum": 123000,
          "hash": "2733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f",
          "transactions": [
              "f8d083015ba98080808080940000...",
          ]
      }
}
```

This endpoint retrieves a specific block from child chain by its hash which was published on root chain

### HTTP Request

`POST /block.get`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
hash | Hex encoded string | HEX-encoded hash of the block
