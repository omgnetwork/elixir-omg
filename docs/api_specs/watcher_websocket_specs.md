
# Watcher - Events

<aside class="warning">TODO Explanation of the WebSocket/ Phoenix Channels mechanism used to receive events</aside>

Exposed via websockets using [Phoenix channels](https://hexdocs.pm/phoenix/channels.html).
Different events are emitted for each topic.

There are the following topics:

## Topic `transfer:{address}`

### Events `address_received` and `address_spent`

`address_received` event informing about that particular address received funds.

`address_spent` event informing about that particular address spent funds.

**NOTE** on finality:
Blocks are validated by the Watcher after a short (not-easily-configurable) finality margin.
By consequence, above events will be emitted no earlier than that finality margin.
In case extra finality is required for high-stakes transactions, the client is free to wait any number of Ethereum blocks (confirmations) on top of `submitted_at_ethheight`.

> An example response of the `address_received` event:

**TODO** the following is an example of current event format. Is likely to change.

```json
{
  "event": "address_received",
  "payload": {
    "child_blknum": 1000,
    "child_block_hash": "0x670ca0195c680659c5d71833d347d8ad8da1cd6cb74fd1fab064ea72705f5e4f",
    "child_txindex": 0,
    "submited_at_ethheight": 36,
    "tx": {
      "signed_tx": {
        "raw_tx": {
          "inputs": [
            {"blknum": 1, "oindex": 0, "txindex": 0},
            {"blknum": 0, "oindex": 0, "txindex": 0},
            {"snip..."}
          ],
          "metadata": null,
          "outputs": [
            {"amount": 7, "currency": "0x0000000000000000000000000000000000000000", "owner": "0x42ca696117ef67092a3e0374378767cd4e3119ee"},
            {"amount": 3, "currency": "0x0000000000000000000000000000000000000000", "owner": "0xa746c588a5a05fda7255063d6de63613bdb21b58"},
            {"amount": 0, "currency": "0x0000000000000000000000000000000000000000", "owner": "0x0000000000000000000000000000000000000000"},
            {"snip..."}
          ]
        },
        "signed_tx_bytes": "0xf901d2f9010cb841bab1a744 <snip> 0000080",
        "sigs": [
          "0xbab1a744b2cd721c774 <snip> 210de00a28b3e4f4abc39dbb1c",
          "<snip>..."
        ]
      },
      "spenders": ["0x42ca696117ef67092a3e0374378767cd4e3119ee"],
      "tx_hash": "0x95429e09250f3bf836a8925aafa325f45f1918088727117ebf8da190fb8627bd"
    }
  },
  "topic": "transfer:0x42ca696117ef67092a3e0374378767cd4e3119ee"
}
```

Both event types have the same structure.

Attribute | Type | Description
--------- | ------- | -----------
`child_blknum` | Integer |
`child_txindex` | Integer |
`child_block_hash` | HEX-encoded string |
`submited_at_ethheight` | integer |
`tx` | object | Structure of signed transaction

## Topic `exit:{address}`

**NOT IMPLEMENTED**

### `exit_finalized` event

**NOT IMPLEMENTED**

> An example of exit_finalized event

```json
{
  "topic": "exit:0xfd5374cd3fe7ba8626b173a1ca1db68696ff3692",
  "ref": null,
  "payload": {
    "event": "exit_finalized",
    "details": {
      "child_blknum": 10000,
      "child_txindex": 12,
      "child_oindex": 0,
      "currency": "0x0000000000000000000000000000000000000000",
      "amount": 100
    },
    "join_ref": null,
    "event": "exit_finalized"
  }  
}
```

Informs that exit is finalized and exited amount of currency was transferred to owner's account.


Attribute | Type | Description
--------- | ------- | -----------
`child_blknum` | Integer |
`child_txindex` | Integer |
`child_oindex` | Integer |
`currency` | HEX-encoded string |
`amount` | integer |


## Topic `childchain`

**NOT IMPLEMENTED**

### Events `new_block`

**NOT IMPLEMENTED**

> An example response of the `new_block` event:

```json
{
  "topic": "childchain",
  "ref": null,
  "payload": {
    "blknum": 100,
    "block_hash": "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
    "ethheight": 423456,
    "timestamp": 1543825669
  },
  "join_ref": null,
  "event": "new_block"
}
```

Informs that a new block has been added to the chain.

Both event types have the same structure.

Attribute | Type | Description
--------- | ------- | -----------
`blknum` | Integer |
`block_hash` | HEX-encoded string |
`ethheight` | integer |
`timestamp` | integer |

#### deposit_spendable

**TODO** the rest of topics

#### fees

**TODO** the rest of topics

# RootChain - Events
The RootChain contract raises certain events on Ethereum
<aside class="warning">TODO We may want to forward these events through the watcher</aside>
<aside class="warning">TODO Some of these events are not currently implemented in the RootChain contract</aside>

 * new_deposit
 * exit_started
 * exit_challenged
 * fees_exited
