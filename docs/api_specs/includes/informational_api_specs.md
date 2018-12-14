# Watcher - Informational API Service

API specification of the Watcher's Informational Service


## Account - Get Balance

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:4000/account.get_balance -d '{"address": "b3256026863eb6ae5b06fa396ab09069784ea8ea"}'
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
    "data": [
        {
            "currency": "BFDF85743EF16CFB1F8D4DD1DFC74C51DC496434",
            "amount": 20
        },
        {
            "currency": "0000000000000000000000000000000000000000",
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
curl -X POST -H "Content-Type: application/json" http://localhost:4000/account.get_utxos -d '{"address": "b3256026863eb6ae5b06fa396ab09069784ea8ea", "limit": 10}'
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
    "data": [
        {
            "txindex": 1,
            "owner": "B3256026863EB6AE5B06FA396AB09069784EA8EA",
            "oindex": 0,
            "currency": "0000000000000000000000000000000000000000",
            "blknum": 1000,
            "amount": 10
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
limit | Integer | Maximum number of utxos to return (default 200)



## Account - Get Transactions

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:4000/account.get_transactions -d '{"address": "b3256026863eb6ae5b06fa396ab09069784ea8ea"}'
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
    "data": [
        {
            "txindex": 12345,
            "txhash": "5DF13A6BF96DBCF6E66D8BABD6B55BD40D64D4320C3B115364C6588FC18C2A21",
            "timestamp": 1540365586,
            "eth_height": 97424,
            "blknum": 68290000,
            "results": [
                {
                    "currency": "0000000000000000000000000000000000000000",
                    "value": -10000
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
curl -X POST -H "Content-Type: application/json" http://localhost:4000/transaction.all -d '{"block": "100", "limit": 50}'
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
    "data": [
        {
            "txindex": 1,
            "txhash": "5DF13A6BF96DBCF6E66D8BABD6B55BD40D64D4320C3B115364C6588FC18C2A21",
            "timestamp": 1540365586,
            "eth_height": 97424,
            "blknum": 68290000,
            "results": [
                {
                    "currency": "0000000000000000000000000000000000000000",
                    "value": 20000000
                }
            ]
        },
        {
            "txindex": 1,
            "txhash": "5DF13A6BF96DBCF6E66D8BABD6B55BD40D64D4320C3B115364C6588FC18C2A21",
            "timestamp": 1540365586,
            "eth_height": 97424,
            "blknum": 68290000,
            "results": [
                {
                    "currency": "12345...",
                    "value": 32
                }
            ]
        }
    ]
}
```

Gets all transactions (can be limited with various filters)

### HTTP Request

`POST /transaction.all`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
block | Integer | Block number to filter by (optional)
address | Hex encoded string | Address to filter by (optional)
limit | Integer | Maximum number of transactions to return (default 200)



## Transaction -  Get

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:4000/transaction.get -d '{"id": "bdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d"}'
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
        "txindex": 1,
        "txhash": "5DF13A6BF96DBCF6E66D8BABD6B55BD40D64D4320C3B115364C6588FC18C2A21",
        "outputs": [
            {
                "txindex": 1,
                "owner": "B3256026863EB6AE5B06FA396AB09069784EA8EA",
                "oindex": 0,
                "currency": "0000000000000000000000000000000000000000",
                "blknum": 3000,
                "amount": 2
            },
            {
                "txindex": 1,
                "owner": "AE8AE48796090BA693AF60B5EA6BE3686206523B",
                "oindex": 1,
                "currency": "0000000000000000000000000000000000000000",
                "blknum": 1000,
                "amount": 7
            }
        ],
        "inputs": [
            {
                "txindex": 1,
                "owner": "B3256026863EB6AE5B06FA396AB09069784EA8EA",
                "oindex": 0,
                "currency": "0000000000000000000000000000000000000000",
                "blknum": 1000,
                "amount": 10
            }
        ],
        "block": {
            "timestamp": 1540365586,
            "hash": "0017372421F9A92BEDB7163310918E623557AB5310BEFC14E67212B660C33BEC",
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
curl -X POST -H "Content-Type: application/json" http://localhost:4000/block.all -d '{"limit": 100}'
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
    "data": [
        {
            "timestamp": 1540365586,
            "hash": "0017372421F9A92BEDB7163310918E623557AB5310BEFC14E67212B660C33BEC",
            "eth_height": 97424,
            "blknum": 68290000
        },
        {
            "timestamp": 1540455586,
            "hash": "0017372421F9A92BEDB7163310918E623557AB5310BEFC14E67212B660C33BEC",
            "eth_height": 97425,
            "blknum": 68290001
        }
    ]
}
```

Gets a block with the given id

### HTTP Request

`POST /block.all`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
limit | Integer | Maximum number of transactions to return (default 200)




## Block - Get

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:4000/block.get -d '{"id": "bdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d"}'
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
        "timestamp": 1540365586,
        "hash": "0017372421F9A92BEDB7163310918E623557AB5310BEFC14E67212B660C33BEC",
        "eth_height": 97424,
        "blknum": 68290000
    }
}
```

Gets a block with the given id

### HTTP Request

`POST /block.get`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
id | Hex encoded string | Hash of the Plasma block


