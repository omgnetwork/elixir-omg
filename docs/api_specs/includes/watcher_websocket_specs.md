
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
    "child_block_hash": "DB32876CC6F26E96B9291682F3AF4A04C2AA2269747839F14F1A8C529CF90225",
    "submited_at_ethheight": 14,
    "tx": {
      "signed_tx": {
        "raw_tx": {
          "amount1": 7,
          "amount2": 3,
          "blknum1": 2001,
          "blknum2": 0,
          "cur12": "0000000000000000000000000000000000000000",
          "newowner1": "051902B7A7D6DCB915CE8FFD3BF46B5E0E16BB9C",
          "newowner2": "E6E3F1307219F68AE4B271CFD493EC8F932C34D9",
          "oindex1": 0,
          "oindex2": 0,
          "txindex1": 0,
          "txindex2": 0
        },
        "sig1": "7B52AB ...",
        "sig2": "2ABGAT ...",
        "signed_tx_bytes": "F8CF83 ..."
      },
      "signed_tx_hash": "0768DC526A093C8C058303832FF3AB45893466D731A34BCF1BF2F866586C0FE6",
      "spender1": "6DCB915C051902B7A7DE8FFD3BF46B5E0E16BB9C",
      "spender2": "5E0E16BB9C19F68AE4B271CFD493EC8F932C34D9"
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
    "block_hash": "0768DC526A093C8C058303832FF3AB45893466D731A34BCF1BF2F866586C0FE6",
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
