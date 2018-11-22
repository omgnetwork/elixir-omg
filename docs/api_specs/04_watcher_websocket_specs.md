
# Watcher - Websocket API

## Topic `transfer:{address}`

### Events `address_received` and `address_spent`

The address_received event informing about that particular address received funds.

The address_spent event informing about that particular address spent funds.

> Both event types have the same structure.
Key | Type | Description
--------- | ------- | -----------
child_blknum | Integer | 
child_txindex | Integer | 
child_block_hash | HEX-encoded string |
submited_at_ethheight | integer |
tx | object | Structure of signed transaction

Blocks are validated by the Watcher after a short (not-easily-configurable) finality margin. By consequence, above events will be emitted no earlier than that finality margin. In case extra finality is required for high-stakes transactions, the client is free to wait any number of Ethereum blocks (confirmations) on top of submitted_at_ethheight.

> An example of JSON document of the `address_received` event:

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

## Topic `byzantine`

### Event `block_withholding`

Event informing that child chain is withholding block which hash was published on root chain.

> Event type have following structure.

Key | Type | Description
--------- | ------- | -----------
blknum | Integer | Number of plasma block


### Event `invalid_block`

Event informing that a particular block is invalid.

> Event type have following structure.

Key | Type | Description
--------- | ------- | -----------
hash | HEX-encoded string | Hash of plasma block
number | Integer | Number of plasma block
error_type | String | 


### Event `invalid_exit`

Event informing that invalid exit has started

> Event type have following structure.

Key | Type | Description
--------- | ------- | -----------
amount | Integer | 
currency | HEX-encoded string | 
owner | HEX-encoded string | 
utxo_pos | Integer |
eth_height | Integer |


### Event `unchallenged_exit`

Notifies about an invalid exit, that is dangerously approaching finalization, without being challneged.
It is a prompt to exit.

> Event type have following structure.

Key | Type | Description
--------- | ------- | -----------
amount | Integer | 
currency | HEX-encoded string | 
owner | HEX-encoded string | 
utxo_pos | Integer |
eth_height | Integer |



## Other planned events
in no particular order or severity
To be clarified...

 * inflight_exit_started
 * inflight_exit_challenged
 * piggyback_to_input
 * piggyback_to_output
 * invalid_fee_exit
 * fees_exited
 * fees
 * new_block
 * new_transaction
 * new_deposit
 * deposit_spendable
 * exit_started
 * exit_challenged
 * exit_success

