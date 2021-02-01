# Simple In-flight Exit

Alice sends tokens to Bob in transaction `tx` which has one input and 2 outputs, one to Bob and one back to herself as change. The block is withheld.

Alice calls `watcher/status.get` and gets a response:

```json
{
    "version": "1",
    "success": true,
    "data": {
        "last_validated_child_block_number": 10000,
        "last_mined_child_block_timestamp": 1535031020,
        "last_mined_child_block_number": 11000,
        "eth_syncing": true,
        "byzantine_events": [
            {
                "event": "block_withholding",
                "details": {
                    "blockhash"  : "DB32876CC6F...",
                    "blocknum"  : 10000,
                }
            }
        ]
    }
}
 ```
She notices that the chain is byzantine and the transaction she just submitted was not included in a block (therefore it's an in-flight transaction)
TODO - How does Alice know that her transaction hasn't been included? Does she have to store the details of every transaction she submits until it is put into a block?

Alice starts an in-flight exit.

#### 1. Get the exit data
`/in_flight_exit.get_data`
```json
 {
    "txbytes": "F3170101C0940000..."
 }
 ```

 response:
```json
 {
    "data": {
        "txbytes": "F3170101C0940000...",
        "sigs": "7C29FB8327F60BBFC62...",
        "input_txs" : [
            "F81891018080808...",
            "2A0341808602A01..."
        ],
        "input_proofs" : [
             "CEDB8B31D1E4C...",
             "A67131D1E904C..."
        ]
    }
 }
 ```

#### 2. Start the IFE
```
RootChain.startInFlightExit(
    response.data.txbytes,
    response.data.input_txs,
    response.data.input_proofs,
    response.data.sigs,
    {"value": inFlightExitBond}
)
```

#### 3. Check status again
```json
{
    "version": "1",
    "success": true,
    "data": {
        "last_validated_child_block_number": 10000,
        "last_mined_child_block_timestamp": 1535031020,
        "last_mined_child_block_number": 11000,
        "eth_syncing": true,
        "byzantine_events": [
            {
                "event": "block_withholding",
                "details": {
                    "blockhash"  : "DB32876CC6F...",
                    "blocknum"  : 10000,
                }
            },
            {
                "event": "piggyback_available",
                "details": {
                    "txbytes": "F3170101C0940000...",
                    "available_outputs" : [
                        {"index": 0, "address": "0x7890..."},
                        {"index": 1, "address": "0x1234..."},
                    ]
                }
            },
        ],
        "in_flight_exits": [
            {
                "txhash": "230C450180808080...",
                "txbytes": "F3170101C0940000...",
                "eth_height" : 615441,
            }
        ]
    }
}
 ```

 Alice sees that her in-flight exit is in progress and she can now piggyback her ouput. Note that as Alice is the sole owner of the inputs, she does not need to piggyback any input.

#### 4. Piggyback the output
The second argument is `5` because she is piggybacking the second output.
```
RootChain.piggybackInFlightExit(
    response.data.txbytes,
    5,
    {"value": piggybackBond}
)
```

After finalization, if nobody challenges the exit, Alice will exit her output and get her `inFlightExitBond` and `piggybackBond` back.

#### 5. Bob finds out that he can piggyback his output
When Bob calls `watcher/status.get` he gets this response:

```json
{
    "version": "1",
    "success": true,
    "data": {
        "last_validated_child_block_number": 10000,
        "last_mined_child_block_timestamp": 1535031020,
        "last_mined_child_block_number": 11000,
        "eth_syncing": true,
        "byzantine_events": [
            {
                "event": "block_withholding",
                "details": {
                    "blockhash"  : "DB32876CC6F...",
                    "blocknum"  : 10000,
                }
            },
            {
                "event": "piggyback_available",
                "details": {
                    "txbytes": "F3170101C0940000...",
                    "available_outputs" : [
                        {"index": 0, "address": "0x7890..."},
                    ]
                }
            },
        ],
        "in_flight_exits": [
            {
                "txhash": "230C450180808080...",
                "txbytes": "F3170101C0940000...",
                "eth_height" : 615441,
                "piggybacked_outputs" : [1]
            }
        ]
    }
}
 ```

Because Alice has already started an exit for the transaction there is a `piggyback_available` event indicating that `output[0]` (Bob's address) can be piggybacked.

#### 6. Bob Piggybacks his output on the IFE
The second argument is `4` because Bob is piggybacking the first output.
```
RootChain.piggybackInFlightExit(
    in_flight_exits[0].txbytes,
    4,
    {"value": piggybackBond}
)
```

After finalization (if nobody challenges the exit) Bob will exit his output and get his `piggybackBond` back.


# Challenge an IFE
To challenge an IFE we must attempt to prove that it is non-canonical by presenting a competing transaction that also spends one its inputs.
If the competing transaction has already been included in a block, then we must present its inclusion proof.
Imagine that Alice's transaction `tx1` in the previous example is a double spend - its `input0` was already spent as `input1` of another transaction `tx0`

Request `watcher/status.get`:

```json
{
    "version": "1",
    "success": true,
    "data": {
        "last_validated_child_block_number": 10000,
        "last_mined_child_block_timestamp": 1535031020,
        "last_mined_child_block_number": 11000,
        "eth_syncing": true,
        "byzantine_events": [
            {
                "event": "block_withholding",
                "details": {
                    "blockhash"  : "DB32876CC6F...",
                    "blocknum"  : 10000,
                }
            },
            {
                "event": "noncanonical_ife",
                "details": {
                    "txbytes": "F3170101C0940000..."
                }
            },
        ],
        "in_flight_exits": [
            {
                "txhash": "230C450180808080...",
                "txbytes": "F3170101C0940000...",
                "eth_height" : 615441,
                "piggybacked_inputs" : [0],
                "piggybacked_outputs" : [0, 1],
            }
        ]
    }
}
 ```

#### 1. Get the competing transaction and its inclusion proof (if available).
`/in_flight_exit.get_competitor`
```json
{
    "txbytes": "F3170101C0940000..."
}
```

response:
```json
{
    "version": "1",
    "success": true,
    "data": {
        "in_flight_txbytes": "F847010180808080940000...",
        "in_flight_input_index": 0,
        "competing_txbytes": "F317010180808080940000...",
        "competing_input_index": 1,
        "challenge_tx_sig": "9A23010180808080940000...",
        "competing_tx_pos": 26000003920000,
        "competing_proof": "004C010180808080940000..."
    }
}
```
Note that if the competing transaction has _not_ been included in a block then its inclusion proof and tx position will not be available. In this case, you should pass "" and 0 to `RootChain.challengeInFlightExitNotCanonical()`

#### 2. Challenge the IFE with an included competitor
```
tx0_data = response.data
RootChain.challengeInFlightExitNotCanonical(
    in_flight_txbytes,
    in_flight_input_index,
    competing_txbytes,
    competing_input_index,
    competing_tx_pos,
    competing_proof,
    competing_sig
)
```

# Respond to an IFE challenge
To respond to a challenge to an IFE, we need to show that the transaction _is_ included. This situation can arise if the user that started the exit did not see the transaction in a block, but subsequently he or another user _did_ see the transaction being put into a block.

`/watcher/status.get` response will contain:
```
    "byzantine_events": [
        {
            "event": "invalid_ife_challenge",
            "details": {
                "txbytes": "F3170101C0940000..."
            }
        }
    ]
```

#### 1. Get the in-flight transaction's inclusion proof.

`/in_flight_exit.prove_canonical`
```json
{
    "txbytes": "F3170101C0940000..."
}
```

response:
```json
{
    "version": "1",
    "success": true,
    "data": {
        "in_flight_txbytes": "F847010180808080940000...",
        "in_flight_tx_pos": 26000003920000,
        "in_flight_proof": "004C010180808080940000..."
    }
}
```

#### 2. Respond to an IFE challenge
```
RootChain.challengeInFlightExitNotCanonical(
    in_flight_txbytes,
    in_flight_tx_pos,
    in_flight_proof,
)
```
If this transaction is the oldest competitor then it is canonical and the IFE succeeds - Bob exits his output.

# Challenging a Piggybacked input
To challenge a piggybacked input we must present a different transaction that spends that input.

`/watcher/status.get` response will contain:
```
    "byzantine_events": [
        {
            "event": "invalid_piggyback",
            "details": {
                "txbytes": "F3170101C0940000...",
                "inputs": [1]
            }
        }
    ]
```

#### 1. Get the transaction that challenges the input

`/in_flight_exit.get_input_challenge_data`
```json
{
    "txbytes": "F3170101C0940000...",
    "input_index": 1
}
```

response:
```json
{
    "version": "1",
    "success": true,
    "data": {
        "in_flight_txbytes": "F3170101C0940000...",
        "in_flight_input_index": 1,
        "spending_txbytes": "F847010180808080940000...",
        "spending_input_index": 1,
        "spending_sig": "9A23010180808080940000..."
    }
}
```

#### 2. Challenge the input
```
RootChain.challengeInFlightExitInputSpent(
    in_flight_tx.txbytes,
    in_flight_tx.input_index,
    spending_tx.txbytes,
    spending_tx.input_index,
    spending_tx.sigs
)
```

# Challenging a Piggybacked output
To challenge a piggybacked output we must present a transaction that spends that output. The in-flight transaction must have been put into a block, but the spending transaction does _not_ need to be in a block.

`/watcher/status.get` response will contain:
```
    "byzantine_events": [
        {
            "event": "invalid_piggyback",
            "details": {
                "txbytes": "F3170101C0940000...",
                "outputs": [0]
            }
        }
    ]
```

#### 1. Get the output's proof of inclusion
`/in_flight_exit.get_output_challenge_data`
```json
{
    "txbytes": "F3170101C0940000...",
    "output_index": 0
}
```

response:
```json
{
    "version": "1",
    "success": true,
    "data": {
        "in_flight_txbytes": "F3170101C0940000...",
        "in_flight_output_pos": 21000634002,
        "in_flight_proof": "03F451067A805540000...",
        "spending_txbytes": "F847010180808080940000...",
        "spending_input_index": 1,
        "spending_sig": "9A23010180808080940000..."
    }
}
```

#### 2. Challenge the output
```
RootChain.challengeInFlightExitOutputSpent(
    in_flight_tx.txbytes,
    in_flight_tx.output_pos,
    in_flight_tx.proof,
    spending_tx.txbytes,
    spending_tx.input_index,
    spending_tx.sigs
)
```
