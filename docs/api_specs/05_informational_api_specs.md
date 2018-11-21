# Watcher - Informational API Service

API specification of the Watcher's Informational Service


## Account - Get Balance

```shell
http POST /account.get_balance address=b3256026863eb6ae5b06fa396ab09069784ea8ea
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
        "currency": "0000000000000000000000000000000000000000",
        "amount": 10
    }
}
```

Responds with account balance for given account address

### HTTP Request

`POST /account.get_balance`

### JSON Body

Key | Value | Description
--------- | ------- | -----------
address | Hex encoded string | Address of the funds owner



## Account - Get Utxos

```shell
http POST /account.get_utxos address=b3256026863eb6ae5b06fa396ab09069784ea8ea
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

### JSON Body

Key | Value | Description
--------- | ------- | -----------
address | Hex encoded string | Address of the account



## Account - Get Transactions

```shell
http POST /account.get_transactions address=b3256026863eb6ae5b06fa396ab09069784ea8ea
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
            "blknum": 68290000
        }
    ]
}
```

Gets a list of transactions.

### HTTP Request

`POST /account.get_transactions`

### JSON Body

Key | Value | Description
--------- | ------- | -----------
address | Hex encoded string | Address of the account



## Transaction -  Get

```shell
http POST /transaction.get id=bdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d
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

### JSON Body

Key | Value | Description
--------- | ------- | -----------
id | Hex encoded string | Hash of the Plasma transaction



## Block - Get

```shell
http POST /block.get id=bdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d
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

`POST /account.get_balance`

### JSON Body

Key | Value | Description
--------- | ------- | -----------
id | Hex encoded string | Hash of the Plasma block


