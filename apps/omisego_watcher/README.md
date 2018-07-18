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

## Using the watcher API

### Endpoints
TODO
 
### Websockets
TODO

#### Events:
TODO add description

##### address_received
Event informing about that particular address received funds.
 
```json
{
    event: "address_received",
    topic: "address:0x463044cc615a34af7621edc9fc0151e6248a6e9c"
    join_ref: nil,
    ref: nil,
    payload: %OmiseGOWatcher.Eventer.Event.AddressReceived{
        child_blknum: 11000, 
        child_block_hash: << 157, 90, 107, 128, 139, 220, 176, 105, 30, 250, 45, 249, 185, 177, 74, 170, 196, 118, 69, 249, 177, 16>>,
        submited_at_ethheight: 15, 
        tx: %OmiseGO.API.State.Transaction.Recovered{
            signed_tx: %OmiseGO.API.State.Transaction.Signed{
                raw_tx: %OmiseGO.API.State.Transaction{
                    amount1: 7, 
                    amount2: 3, 
                    blknum1: 2001, 
                    blknum2: 0, 
                    cur12: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>, 
                    newowner1: <<70, 48, 68, 204, 97, 90, 52, 175, 118, 33, 237, 201, 252, 1, 81, 230, 36, 138, 110, 156>>, 
                    newowner2: <<226, 3, 142, 147, 79, 27, 150, 233, 221, 233, 113, 37, 159, 88, 68, 106, 126, 117, 174, 177>>, 
                    oindex1: 0, 
                    oindex2: 0, 
                    txindex1: 0, 
                    txindex2: 0
                }, 
                sig1: <<232, 31, 114, 115, 166, 0, 192, 73, 92, 182, 161, 159, 87, 134, 127, 160, 166, 182, 194, 48, 232, 146, 162, 125, 174, 177, 75, 141, 201, 82, 209, 91, 53, 159, 44, 220, 165, 170, 60, 159, ...>>, 
                sig2: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...>>, 
                signed_tx_bytes: <<248, 207, 130, 7, 209, 128, 128, 128, 128, 128, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 148, 70, 48, 68, 204, 97, 90, ...>>
            }, 
            signed_tx_hash: <<156, 68, 161, 217, 149, 230, 15, 61, 144, 154, 231, 145, 220, 232, 177, 127, 112, 148, 18, 220, 156, 64, 106, 39, 89, 146, 113, 192, 193, 2, 236, 157>>, 
            spender1: <<70, 48, 68, 204, 97, 90, 52, 175, 118, 33, 237, 201, 252, 1, 81, 230, 36, 138, 110, 156>>, 
            spender2: nil
        }
    }
}
```

##### address_spent
Event informing about that particular address spent funds.

