# Watcher - Informational API Service

API specification of the Watcher's Informational Service


## Account - Get Balance

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/account.get_balance -d '{"address": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea"}'
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
    "version": "1.0",
    "success": true,
    "data": [
        {
            "currency": "0xbfdf85743ef16cfb1f8d4dd1dfc74c51dc496434",
            "amount": 20
        },
        {
            "currency": "0x0000000000000000000000000000000000000000",
            "amount": 1000000000
        }
    ]
}
```

Returns the balance of each currency for the given account address

### HTTP Request

`POST /account.get_balance`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
address | Hex encoded string | Address of the funds owner



## Account - Get Utxos

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/account.get_utxos -d '{"address": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea"}'
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
    "version": "1.0",
    "success": true,
    "data": [
        {
            "txindex": 1,
            "owner": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea",
            "oindex": 0,
            "currency": "0x0000000000000000000000000000000000000000",
            "blknum": 1000,
            "amount": 10,
            "utxo_pos": 10000000010000000
        }
    ]
}
```

Gets all utxos belonging to the given address

### HTTP Request

`POST /account.get_utxos`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
address | Hex encoded string | Address of the account



## Account - Get Transactions

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/account.get_transactions -d '{"address": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea"}'
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
    "version": "1.0",
    "success": true,
    "data": [
        {
            "block": {
                "timestamp": 1540365586,
                "hash": "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
                "eth_height": 97424,
                "blknum": 68290000
            },
            "txindex": 0,
            "txhash": "0x5df13a6bf96dbcf6e66d8babd6b55bd40d64d4320c3b115364c6588fc18c2a21",
            "results": [
                {
                    "currency": "0x0000000000000000000000000000000000000000",
                    "value": 20000000
                }
            ]
        }
    ]
}
```

Gets a list of transactions.

### HTTP Request

`POST /account.get_transactions`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
address | Hex encoded string | Address of the account
limit | Integer | Maximum number of transactions to return (default 200)



## Transaction -  Get All

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/transaction.all -d '{"blknum": "100", "limit": 50}'
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
    "version": "1.0",
    "success": true,
    "data": [
        {
            "block": {
                "timestamp": 1540365586,
                "hash": "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
                "eth_height": 97424,
                "blknum": 68290000
            },
            "txindex": 0,
            "txhash": "0x5df13a6bf96dbcf6e66d8babd6b55bd40d64d4320c3b115364c6588fc18c2a21",
            "results": [
                {
                    "currency": "0x0000000000000000000000000000000000000000",
                    "value": 20000000
                }
            ]
        },
        {
            "block": {
                "timestamp": 1540365586,
                "hash": "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
                "eth_height": 97424,
                "blknum": 68290000
            },
            "txindex": 1,
            "txhash": "0xabcd3a6bf96dbcf6e66d8babd6b55bd40d64d4320c3b115364c6588fc18c2a21",
            "results": [
                {
                    "currency": "0xbfdf85743ef16cfb1f8d4dd1dfc74c51dc496434",
                    "value": 32
                }
            ]
        }
    ]
}
```

Gets all transactions (can be limited with various filters).

Digests the details of the transaction, by listing the value of outputs, aggregated by currency.
Intended to be used when presenting the little details about multiple transactions.
For all details queries to `/transaction.get` should be made using the transaction's hash provided.

### HTTP Request

`POST /transaction.all`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
blknum | Integer | Block number to filter by (optional)
address | Hex encoded string | Address to filter by (optional)
limit | Integer | Maximum number of transactions to return (default 200)



## Transaction -  Get

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/transaction.get -d '{"id": "0xbdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d"}'
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
    "version": "1.0",
    "success": true,
    "data": {
        "txindex": 1,
        "txhash": "0x5df13a6bf96dbcf6e66d8babd6b55bd40d64d4320c3b115364c6588fc18c2a21",
        "outputs": [
            {
                "txindex": 1,
                "owner": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea",
                "oindex": 0,
                "currency": "0x0000000000000000000000000000000000000000",
                "blknum": 68290000,
                "amount": 2
            },
            {
                "txindex": 1,
                "owner": "0xae8ae48796090ba693af60b5ea6be3686206523b",
                "oindex": 1,
                "currency": "0x0000000000000000000000000000000000000000",
                "blknum": 68290000,
                "amount": 7
            }
        ],
        "inputs": [
            {
                "txindex": 1,
                "owner": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea",
                "oindex": 0,
                "currency": "0x0000000000000000000000000000000000000000",
                "blknum": 1000,
                "amount": 10
            }
        ],
        "txbytes": "0x3eb6ae5b06f3...",
        "block": {
            "timestamp": 1540365586,
            "hash": "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
            "eth_height": 97424,
            "blknum": 68290000
        }
    }
}
```

Gets a transaction with the given id

### HTTP Request

`POST /transaction.get`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
id | Hex encoded string | Hash of the Plasma transaction



## Block - Get all

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/block.all -d '{"from_blknum": 68290001, "limit": 2}'
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
    "version": "1.0",
    "success": true,
    "data": [
        {
            "timestamp": 1540365586,
            "hash": "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
            "eth_height": 97424,
            "blknum": 68290000
        },
        {
            "timestamp": 1540455586,
            "hash": "0x0057d0f13a6bf96dbcf6e66d8babd6b55bd40d64d4320c3b115364c6588fc18c",
            "eth_height": 97425,
            "blknum": 68290001
        }
    ]
}
```

**`/block.xxx` endpoints not implemented yet and might undergo design changes**:

Gets all blocks (with a limit on the number of blocks to return).

### HTTP Request

`POST /block.all`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
limit | Integer | Maximum number of blocks to return (default 200)
from_blknum | Integer | The block number of the latest block in the list to be returned. Optional - if not specified, latest block will be the current block. **Not Implemented Yet**




## Block - Get

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/block.get -d '{"id": "0xbdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d"}'
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
    "version": "1.0",
    "success": true,
    "data": {
        "timestamp": 1540365586,
        "hash": "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
        "eth_height": 97424,
        "blknum": 68290000
    }
}
```

**`/block.xxx` endpoints not implemented yet and might undergo design changes**:

Gets a block with the given id

### HTTP Request

`POST /block.get`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
id | Hex encoded string | Hash of the Plasma block
