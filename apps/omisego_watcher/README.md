# OmiseGO Watcher

**IMPORTANT NOTICE: Heavily WIP, expect anything**

The Watcher is an observing node that connects to Ethereum and the child chain server's API.
It exposes the information it gathers via a REST interface (Phoenix)
For the responsibilities and design of the watcher see [Tesuji Plasma Blockchain Design document](FIXME link pending).

**TODO** write proper README after we distill how to run this.

## Setting up and running the watcher

```
cd apps/omisego_watcher
# FIXME: wouldn't work yet but would belong here: mix run --no-start -e 'OmiseGO.DB.init()'
iex --sname watcher -S mix
```

## Setting up (developer's environment)

  - setup and run the child chain server in developer's environment
  - setup and run the watcher pointing to the same `omisego_eth` configuration (with the contract address) as the child chain server

## Using the watcher

FIXME adapt to how it actually works


##Endpoints
TODO
 
## Websockets

Exposed websockets are using [Phoniex channels](https://hexdocs.pm/phoenix/channels.html) feature. 
Different events are emitted for each topic.

### Topics:

### transfer:ethereum_address

#### Events:

##### address_received and address_spent
`address_received` event informing about that particular address received funds.

`address_spent` vent informing about that particular address spent funds.

Blocks are validated by the Watcher after a short (not-easily-configurable) finality margin. By consequence, above events will be emitted no earlier than that finality margin.
In case extra finality is required for high-stakes transactions, the client is free to wait any number of Ethereum blocks (confirmations) on top of submitted_at_ethheight

```json
{
  "topic": "transfer:0xfd5374cd3fe7ba8626b173a1ca1db68696ff3692",
  "ref": null,
  "payload": {
    "child_blknum": 10000,
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

### spends:ethereum_address

#### Events:

##### address_spent

### receives:ethereum_address

#### Events:

##### address_received

### byzantine_invalid_exit

#### Events:

##### in_flight_exit

##### piggyback

##### exit_from_spent

### byzantine_bad_chain

#### Events:

##### invalid_block
Event informing about that particular block is invalid.
 
##### block_withholding
Event informing about that the child chain is withholding block.

##### invalid_fee_exit

### TODO block 

### TODO deposit_spendable

### TODO fees

#### Events:

##### fees_exited

