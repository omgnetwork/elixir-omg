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
See docs on [`unchallenged_exit` condition](../exit_validation.md#unchallenged-exit-condition) for more details.


#### `invalid_block`
> An invalid_block event

```json
{
    "event": "invalid_block",
    "details": {
        "blockhash"  : "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
        "blknum"  : 10000,
        "error_type": "tx_execution"
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
        "hash"  : "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
        "blknum"  : 10000
    }
}
```

The ChildChain is withholding a block whose hash has been published on the root chain. User should exit.

#### `non_canonical_ife`
> A noncanonical_ife event

```json
{
    "event": "non_canonical_ife",
    "details": {
        "txbytes": "0xf3170101c0940000..."
    }
}
```

An in-flight exit of a non-canonical transaction has been started. It should be challenged.

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
This event is reported only for in-flight exits from transactions that have not been included in a block.
If input or output of exiting transaction is piggybacked it does not show up as available for piggybacking.
When in-flight exit is finalized, transaction's inputs and outputs are not available for piggybacking.

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

Event details:

Attribute | Type | Description
--------- | ------- | -----------
txbytes | Hex encoded string | The in-flight transaction that the event relates to
inputs | Integer array | A list of invalid piggybacked inputs
outputs | Integer array | A list of invalid piggybacked outputs
