# Watcher

API specification of the Watcher's security-critical Service

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

Gets all utxos belonging to the given address.
<aside class="notice">
Note that this is a performance intensive call and should only be used if the chain is byzantine and the user needs to retrieve utxo information to be able to exit.
Normally an application should use the Informational API's <a href="#account-get-utxos">Account - Get Utxos</a> instead.
This version is provided in case the Informational API is not available.
</aside>

### HTTP Request

`POST /account.get_utxos`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
address | Hex encoded string | Address of the account



## Utxo - Get Challenge Data

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/utxo.get_challenge_data -d '{"utxo_pos": 10000000010000000}'
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
        "input_index": 0,
        "output_id": 3000000000000,
        "sig": "0x6bfb9b2dbe32...",
        "txbytes": "0x3eb6ae5b06f3..."
    }
}
```

Gets challenge data for a given utxo exit

### HTTP Request

`POST /utxo.get_challenge_data`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
utxo_pos | Integer | Utxo position (encoded as single integer, the way contract represents them)



## Utxo - Get Exit Data

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/utxo.get_exit_data -d '{"utxo_pos": 10000000010000000}'
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
        "utxo_pos": 10000000010000000,
        "txbytes": "0x3eb6ae5b06f3...",
        "proof": "0xcedb8b31d1e4..."
    }
}
```

Gets exit data for a given utxo

### HTTP Request

`POST /utxo.get_exit_data`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
utxo_pos | Integer | Utxo position (encoded as single integer, the way contract represents them)



## Transaction - Submit

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/transaction.submit -d '{"transaction": "0xf8d083015ba98080808080940000..."}'
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
          "blknum": 123000,
          "txindex": 111,
          "txhash": "0xbdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d"
      }
}
```

Watcher passes signed transaction to the child chain only if it's secure (better explaination needed)

### HTTP Request

`POST /transaction.submit`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
transaction | Hex encoded string | Signed transaction RLP-encoded to bytes and HEX-encoded to string




## Status

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:4000/status.get
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
        "last_validated_child_block_number": 10000,
        "last_mined_child_block_timestamp": 1535031020,
        "last_mined_child_block_number": 11000,
        "eth_syncing": true,
        "byzantine_events":
        [
            {
                "event": "invalid_exit",
                "details": {
                    "eth_height"  : 615440,
                    "utxo_pos"  : 10000000010000000,
                    "owner"  : "0xb3256026863eb6ae5b06fa396ab09069784ea8ea",
                    "currency"  : "0x0000000000000000000000000000000000000000",
                    "amount" : 100
                }
            }
        ],
        "inflight_txs": [
            {
                "txhash": "0xbdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d",
                "txbytes": "0x3eb6ae5b06f3...",
                "input_addresses": [
                    "0x1234..."
                ],
                "ouput_addresses": [
                    "0x1234...",
                    "0x7890..."
                ],
            }
        ],
        "inflight_exits": [
            {
                "txhash": "0x5df13a6bf96dbcf6e66d8babd6b55bd40d64d4320c3b115364c6588fc18c2a21",
                "txbytes": "0xf3170101c0940000...",
                "eth_height" : 615441,
                "piggybacked_inputs" : [1],
                "piggybacked_outputs" : [0, 1]
            }
        ]
    }
}
```

Returns information about the current state of the child chain and the watcher.

<aside class="warning">
The most critical function of the Watcher is to monitor the ChildChain and report dishonest activity.
The user must call the `/status` endpoint periodically to check. Any situation that requires the user to either exit or challenge an invalid exit will be included in the `byzantine_events` field.
</aside>

<aside class="notice">
Note that `inflight_txs` will be implemented in a later version.
</aside>


### HTTP Request

`POST /status`

### Request Body

No parameters are required.

### Byzantine events
All of the following events indicate byzantine behaviour and that the user should either exit or challenge.

#### `invalid_exit`
> An invalid_exit event

```json
{
    "event": "invalid_exit",
    "details": {
        "eth_height"  : 3521678,
        "utxo_pos"  : 10000000010000000,
        "owner"  : "0xb3256026863eb6ae5b06fa396ab09069784ea8ea",
        "currency"  : "0x0000000000000000000000000000000000000000",
        "amount" : 100
    }
}
```

Indicates that an invalid exit is occurring. It should be challenged.


#### `unchallenged_exit`
> An unchallenged_exit event

```json
{
    "event": "unchallenged_exit",
    "details": {
        "eth_height"  : 3521678,
        "utxo_pos"  : 10000000010000000,
        "owner"  : "0xb3256026863eb6ae5b06fa396ab09069784ea8ea",
        "currency"  : "0x0000000000000000000000000000000000000000",
        "amount" : 100
    }
}
```

Indicates that an invalid exit is dangerously close to finalization and hasn't been challenged. User should exit.


#### `invalid_block`
> An invalid_block event

```json
{
    "event": "invalid_block",
    "details": {
        "blockhash"  : "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
        "blocknum"  : 10000,
    }
}
```

An invalid block has been added to the chain. User should exit.


#### `block_withholding`
> A block_withholding event

```json
{
    "event": "block_withholding",
    "details": {
        "blockhash"  : "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
        "blocknum"  : 10000,
    }
}
```

The ChildChain is withholding a block whose hash has been published on the root chain. User should exit.

#### `noncanonical_ife`
> A noncanonical_ife event

```json
{
    "event": "noncanonical_ife",
    "details": {
        "txbytes": "0xf3170101c0940000..."
    }
}
```

An in-flight exit of a non-canonical transaction has been started. It should be challenged.
<aside class="warning"> Not Implemented Yet.</aside>

Event details:

Attribute | Type | Description
--------- | ------- | -----------
txbytes | Hex encoded string | The in-flight transaction that the event relates to

#### `invalid_ife_challenge`
> A invalid_ife_challenge event

```json
{
    "event": "invalid_ife_challenge",
    "details": {
        "txbytes": "0xf3170101c0940000..."
    }
}
```

A canonical in-flight exit has been challenged. The challenge should be responded to.
<aside class="warning"> Not Implemented Yet.</aside>

Event details:

Attribute | Type | Description
--------- | ------- | -----------
txbytes | Hex encoded string | The in-flight transaction that the event relates to

#### `piggyback_available`
> A piggyback_available event

```json
{
    "event": "piggyback_available",
    "details": {
        "txbytes": "0xf3170101c0940000...",
        "available_outputs" : [
            {"index": 0, "address": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea"},
            {"index": 1, "address": "0x488f85743ef16cfb1f8d4dd1dfc74c51dc496434"},
        ],
        "available_inputs" : [
            {"index": 0, "address": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea"}
        ],
    }
}
```

An in-flight exit has been started and can be piggybacked. If all inputs are owned by the same address, then `available_inputs` will not be present.
<aside class="warning"> Not Implemented Yet.</aside>

Event details:

Attribute | Type | Description
--------- | ------- | -----------
txbytes | Hex encoded string | The in-flight transaction that the event relates to
available_outputs | Object array | The outputs (index and address) available to be piggybacked
available_inputs | Object array | The inputs (index and address) available to be piggybacked

#### `invalid_piggyback`
> A invalid_piggyback event

```json
{
    "event": "invalid_piggyback",
    "details": {
        "txbytes": "0xf3170101c0940000...",
        "inputs": [1],
        "outputs": [0]
    }
}
```

An invalid piggyback is in process. Should be challenged.
<aside class="warning"> Not Implemented Yet.</aside>

Event details:

Attribute | Type | Description
--------- | ------- | -----------
txbytes | Hex encoded string | The in-flight transaction that the event relates to
inputs | Integer array | A list of invalid piggybacked inputs
outputs | Integer array | A list of invalid piggybacked outputs



## Inflight Exit - Get Exit Data

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/inflight_exit.get_data -d '{"txbytes": "0xf3170101c0940000..."}'
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
        "in_flight_tx": "0xf3170101c0940000...",
        "input_txs": "0xa3470101c0940000...",
        "input_txs_inclusion_proofs" : "0xcedb8b31d1e4...",
        "in_flight_tx_sigs" : "0x6bfb9b2dbe32...",
    }
}
```

Gets exit data for an in-flight exit. Exit data are arguments to `startInFlightExit` root chain contract function.

### HTTP Request

`POST /inflight_exit.get_data`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
txbytes | Hex encoded string | The in-flight transaction



## Inflight Exit - Get Competitor

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/inflight_exit.get_competitor -d '{"txbytes": "0xf3170101c0940000..."}'
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
        "inflight_txbytes": "0xf3170101c0940000...",
        "inflight_input_index": 1,
        "competing_txbytes": "0x5df13a6bee20000...",
        "competing_input_index": 1,
        "competing_sig": "0xa3470101c0940000...",
        "competing_txid": 2600003920012,
        "competing_proof": "0xcedb8b31d1e4..."
    }
}
```

Returns a competitor to an in-flight exit. Note that if the competing transaction has not been put into a block `competing_txid` and `competing_proof` will not be returned.

### HTTP Request

`POST /inflight_exit.get_competitor`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
txbytes | Hex encoded string | The in-flight transaction



## Inflight Exit - Show Canonical

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/inflight_exit.prove_canonical -d '{"txbytes": "0xf3170101c0940000..."}'
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
        "inflight_txbytes": "0xf3170101c0940000...",
        "inflight_txid": 2600003920012,
        "inflight_proof": "0xcedb8b31d1e4..."
    }
}
```

To respond to a challenge to an in-flight exit, this proves that the transaction has been put into a block (and therefore is canonical).

### HTTP Request

`POST /inflight_exit.prove_canonical`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
txbytes | Hex encoded string | The in-flight transaction



## Inflight Exit - Get Input Challenge Data

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/inflight_exit.get_input_challenge_data -d '{"txbytes": "0xf3170101c0940000...", "input_index": 1}'
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
        "inflight_txbytes": "0xf3170101c0940000...",
        "inflight_input_index": 1,
        "spending_txbytes": "0x5df13a6bee20000...",
        "spending_input_index": 1,
        "spending_sig": "0xa3470101c0940000..."
    }
}
```

Gets the data to challenge an invalid input piggybacked on an in-flight exit

### HTTP Request

`POST /inflight_exit.get_input_challenge_data`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
txbytes | Hex encoded string | The in-flight transaction
input_index | Integer | The index of the invalid input



## Inflight Exit - Get Output Challenge Data

```shell
curl -X POST -H "Content-Type: application/json" http://localhost:7434/inflight_exit.get_output_challenge_data -d '{"txbytes": "0xf3170101c0940000...", "output_index": 0}'
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
        "inflight_txbytes": "0xf3170101c0940000...",
        "inflight_output_pos": 21000634002,
        "inflight_proof": "0xcedb8b31d1e4...",
        "spending_txbytes": "0x5df13a6bee20000...",
        "spending_input_index": 1,
        "spending_sig": "0xa3470101c0940000..."
    }
}
```

Gets the data to challenge an invalid output piggybacked on an in-flight exit

### HTTP Request

`POST /inflight_exit.get_output_challenge_data`

### Request Body

Attribute | Type | Description
--------- | ------- | -----------
txbytes | Hex encoded string | The in-flight transaction
output_index | Integer | The index of the invalid output
