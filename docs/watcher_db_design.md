# Watcher database design

Watcher benefits from two databases approach:
* rocksdb - key-value database that child chain state uses for transaction validation
* watcherDb - PostgreSQL database that stores transactions and contains data needed for challenges and exits. It provides user interface with the data of user's concern (e.g: did I pay the electricity bill, who sent me money last week).

[PostgreSQL Schema Diagram](https://docs.google.com/drawings/d/14_0bfUGGWarndNWwpzA2Nznll4PHLbefvQy05B2LB38/edit?usp=sharing)

## The blocks table
Stores data about blocks: hash, timestamp when block was mined, Ethereum height is was published on.

|**blocks**|||
|:-:|:-|:-|
|blknum|bigint|Pk|
|hash|bytea||
|timestamp|integer||
|eth_height|bigint||

## The transactions table
Stores information about transactions.

|**transactions**|||
|:-:|:-|:-|
|txhash|bytea|Pk|
|blknum|integer|Fk(blocks, blknum), UI(blknum, txindex)|
|txindex|integer|UI^|
|txbytes|bytea||
|sent_at|timestamp|UTC (w/o TZ)|

## The transaction inputs and outputs table
Stores inputs and outputs of transactions. Utxo is a record in `txoutputs` table where `spending_txhash` is `NULL`. `proof` field is needed for exiting an utxo. We compute a proof from all the transactions contained in the same block as the transaction that created the utxo.

|**txoutputs**|||
|:-:|:-|:-|
|blknum|integer|Pk(blknum, txindex, oindex)|
|txindex|integer|Pk^|
|oindex|integer|Pk^|
|creating_txhash|bytea)|Fk(transactions, (txhash)), NULL|
|creating_deposit|bytea)|Fk(eth_events, (hash)), NULL|
|spending_txhash|bytea|Fk(transactions, (txhash)), NULL|
|spending_exit|bytea|Fk(eth_event, (hash)), NULL|
|spending_tx_oindex|integer||
|owner|bytea||
|amount|numeric(81,0)||
|currency|bytea||
|proof|bytea||
|child_chain_utxohash|bytea|UI|
|inserted_at|datetime|UTC (w/ TZ)|
|updated_at|datetime|UTC (w/ TZ)|

## The Ethereum events table
Stores events logged in root contract, such as _deposits_ or _exits_.

|**ethevents**|||
|:-:|:-|:-|
|root_chain_txhash|bytea|Pk(root_chain_txhash, log_index)|
|event_type|integer|Pk^|
|event_type|varchar(124)||
|root_chain_txhash_event|bytea|UI|
|inserted_at|datetime|UTC (w/ TZ)|
|updated_at|datetime|UTC (w/ TZ)|


## The ethevents_txoutputs table
A table for many-to-many relationships between Ethereum events and UTXOs.

|**ethevents_txoutputs**|||
|:-:|:-|:-|
|root_chain_txhash_event|bytea|Pk(root_chain_txhash_event, child_chain_utxohash), FK(ethevents, (root_chain_txhash_event))|
|child_chain_utxohash|bytea|Pk^, FK(txoutputs, (child_chain_utxohash))|
|inserted_at|datetime|UTC (w/ TZ)|
|updated_at|datetime|UTC (w/ TZ)|


## Examples of queries against the tables

### 1. get a transaction with inputs and outputs
```
select t.*, i.*, o.*
  from transactions t
  join TxOutput i on i.spending_txhash = t.txhash
  join TxOutput o on o.creating_txhash = t.txhash
 where t.txhash = @txhash
```

### 2. get all transactions satisfying some criteria
... As in the previous example but with modified where clause.

### 3. get utxo position by owner address for spend
```
select o.blknum, o.txindex, o.oindex
  from txoutputs o
 where o.owner = @owner_address
```

### 4. get utxo position by owner address for exit
... see previous point

### 5. add utxo when deposit detected
```
insert hash, deposit_blknum, deposit_txindex, event_type
  into ethevents
values (@hash, @blknum, 0, "deposit")

insert creating_deposit, blknum, txindex, oindex, owner, amount, currency
  into txoutputs
values (@hash, @blknum, 0, 0, ...)
```

### 6. spend utxo when exit finalized
```
insert hash, event_type
  into ethevents
values (@hash, "exit")

update txoutputs
   set spending_exit = @hash
 where ...
```

### 7. get exit data by an utxo position
For exit we need: proof that transaction is included in block.

(**NOTE** that this is only optionally served by `WatcherDB`.
Normally one expects this to be served by the `security-critical` Watcher mode, which doesn't run `WatcherDB`)

```
select (t.txhash, t.txbytes)
  into @out
from transactions t
  join txoutputs o on o.creating_txhash = t.txhash
 where (t.blknum, t.txindex, o.oindex) = @position

select t.txhash
  from transactions t
 where t.blknum  == @blknum
```

### 8. get all ethereum events for existing utxos
```
SELECT CASE WHEN t.child_chain_utxohash IS NULL THEN NULL
            WHEN t.child_chain_utxohash IS NOT NULL THEN concat('0x', encode(t.child_chain_utxohash::bytea, 'hex'))
       END AS child_chain_utxohash,
       CASE WHEN e.root_chain_txhash_event IS NULL THEN NULL
            WHEN e.root_chain_txhash_event IS NOT NULL THEN concat('0x', encode(e.root_chain_txhash_event::bytea, 'hex'))
       END AS root_chain_txhash_event,
       CASE WHEN e.root_chain_txhash IS NULL THEN NULL
            WHEN e.root_chain_txhash IS NOT NULL THEN concat('0x', encode(e.root_chain_txhash::bytea, 'hex'))
       END AS root_chain_txhash,
       blknum, txindex, oindex,
       amount,
       log_index,
       event_type
FROM txoutputs t
    LEFT OUTER JOIN ethevents_txoutputs et ON t.child_chain_utxohash = et.child_chain_utxohash
      LEFT OUTER JOIN ethevents e ON et.root_chain_txhash_event = e.root_chain_txhash_event;
```
