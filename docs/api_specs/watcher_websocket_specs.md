
# Watcher - Events

<aside class="warning">TODO Explanation of the WebSocket/ Phoenix Channels mechanism used to receive events</aside>

## Topic `transfer:{address}`

### Events `address_received` and `address_spent`

> An example response of the `address_received` event:

```json
{
  "topic": "transfer:0xfd5374cd3fe7ba8626b173a1ca1db68696ff3692",
  "ref": null,
  "payload": {
    "child_blknum": 10000,
    "child_txindex": 12,
    "child_block_hash": "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
    "submited_at_ethheight": 14,
    "tx": {
      "signed_tx": {
        "raw_tx": {
          "amount1": 7,
          "amount2": 3,
          "blknum1": 2001,
          "blknum2": 0,
          "cur12": "0x0000000000000000000000000000000000000000",
          "newowner1": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea",
          "newowner2": "0xae8ae48796090ba693af60b5ea6be3686206523b",
          "oindex1": 0,
          "oindex2": 0,
          "txindex1": 0,
          "txindex2": 0
        },
        "sig1": "0x6bfb9b2dbe32 ...",
        "sig2": "0xcedb8b31d1e4 ...",
        "signed_txbytes": "0xf3170101c0940000..."
      },
      "txhash": "0xbdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d",
      "spender1": "0xbfdf85743ef16cfb1f8d4dd1dfc74c51dc496434",
      "spender2": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea"
    }
  },
  "join_ref": null,
  "event": "address_received"
}
```

The address_received event informing about that particular address received funds.

The address_spent event informing about that particular address spent funds.

Both event types have the same structure.

Attribute | Type | Description
--------- | ------- | -----------
child_blknum | Integer |
child_txindex | Integer |
child_block_hash | HEX-encoded string |
submited_at_ethheight | integer |
tx | object | Structure of signed transaction


## Topic `childchain`

### Events `new_block`

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
blknum | Integer |
block_hash | HEX-encoded string |
ethheight | integer |
timestamp | integer |



# RootChain - Events
The RootChain contract raises certain events on Ethereum
<aside class="warning">TODO We may want to forward these events through the watcher</aside>
<aside class="warning">TODO Most of these events are not currently implemented in the RootChain contract</aside>

 * new_deposit
 * exit_started
 * exit_challenged
 * exit_finalized
 * fees_exited
