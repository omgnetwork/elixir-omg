Watcher database design
===

Watcher will be still benefit from two databases approach, as described:
* leveldb - database behind the State used for chaildchain block validation
* watcherDb - postgres database containing info for challenges & exits as well as supporting user interface with the data of user's concern (e.g: did I pay the electricity bill, who sent me money last week, ...)

This separation into two DBs is drived mostly by *Limited Custody exchange* case where exchange is using address pool to send transactions from, and uses multiple Watcher instances, each managing some address pool partition. Then we assume each instance will validate the chain itself not relying to others. However all instances may use common (shared) WatcherDb to handle exits & challenges.

## LevelDb
We need it be aligned with the API.State as much as possible - no Watcher specific changes to this database are planned.

## WatcherDb
Here we describe new database structure.


## The Transaction table
Stores information about transactions. Since we introduce checkpoints here, (see: The Checkpoint table below). One can think that table cointains all transactions not older than the last checkpoint block which are necessary to exit from the Utxo or challenge exits. For non-challenging Watchers it can contain only transactions which funding or spending tokens for the addresses of interest.

|**Transaction**|||
|:-:|:-|:-|
|txhash|bytea(32)|Pk|
|blknum|int8|UI(blknum,txind)|
|txindex|int4|UI^|
|txbytes|bytea(max)|inputs, outputs, curr, signs|
|sent_at|timestamp|w/o TZ in UTC|
|eth_height|int8||


## The Txoutput table
Stores information about input & outputs to the transactions. The Utxo is an record in `TxOutput` table where `spending_txhash` is `NULL`. Prove field is only needed for exiting the Utxo from the checkpoint, as exiting recent utxos we can recompute the prove from transactions contained in the same block when needed. 

|**Txoutput**|||
|:-:|:-|:-|
|blknum|int8||
|txindex|int4||
|oindex|int2||
|creating_txhash|bytea(32)|Fk(Tx, (txhash)), NULL|
|creating_deposit|bytea(32)|Fk(Eth_event, (hash)), NULL|
|spending_txhash|bytea(32)|Fk(Tx, (txhash)), NULL|
|spending_exit|bytea(32)|Fk(Eth_event, (hash)), NULL|
|spending_tx_oindex|int2||
|owner|bytea(20)||
|amount|decimal(81,0)||
|currency|bytea(20)||
|proof|bytea(max)||

## The Ethereum events table
Events observed in root contract logs such as _deposits_ or _exits_. Since for now the table provides little value will not be created

|**Ethevent**|||
|:-:|:-|:-|
|hash|bytea(32)|Pk|
|deposit_blknum|int8||
|deposit_txindex|int4||
|event_type|deposit\|exit||

## The Checkpoint table
Note: this feature are still in review and will appear later. Stores information about checkpoints published by the Operator on rootchain. One can think about checkpoint as moving of all Utxos created by chailchain Txs before particular blknum into deposits in the checkpoint. So after the checkpoint creation block to exit the Utxo one need to prove that utxo is contained in the last checkpoint. Challenger needs to prove that the Utxo was spend by the transaction included in block newer than the checkpoint creation block.


## The Account table
 Note: this feature are still in review and will appear later. To be able to exit from Utxos that was included in the checkpoint we need to recompute proof for each accounts (utxo owners) we care about. When new checkpoint is created and utxo is still unspend we need to compute proof it's contained in the checkpoint.

## Example of queries against new database structure

### 1. get transaction with all details
```
select t.*, i.*, o.*
  from Transaction t
  join TxOutput i on i.spending_txhash = t.txhash 
  join TxOutput o on o.creating_txhash = t.txhash
 where t.txhash = @txhash
```

### 2. query as above but for all transactions satisfing some criteria
... just modyfication of `where` clause

### 3. get utxo position by owner address for spend
```
select o.blknum, o.txindex, o.oindex
  from TxOutput o 
 where o.owner = @address
```

### 4. get utxo position by owner address for exit
... see previous point

### 5. add utxo when deposit detected
```
insert hash, deposit_blknum, deposit_txindex, event_type 
  into EthEvent
values (@hash, @blknum, 0, "deposit")

insert creating_deposit, blknum, txindex, oindex, owner, amount, currency
  into TxOutput 
values (@hash, @blknum, 0, 0, ...)
```

### 6. spent utxo when exit finalized
```
insert hash, event_type 
  into EthEvent
values (@hash, "exit")

update TxOutput 
   set spending_exit = @hash
 where ...
```

### 7. get exit data by utxo position
For exit we need: proof that tx has been included in block
```
select (t.txhash, t.txbytes) 
  into @out
from Transaction t
  join TxOutput o on o.creating_txhash = t.txhash
 where (t.blknum, t.txindex, o.oindex) = @position
 
select t.txhash
  from Transaction t
 where t.blknum  == @blknum
```

### 8. get challenge data to utxo exit
For challenge we need: proof that spending tx has been included in block and spending (input) index of (u)txo. See prevoius point as well.
```
select (t.txhash, t.txbytes, i.spending_tx_oindex) 
  into @out
  from from Transaction t
  join TxOutput i on i.spending_txhash = t.txhash 
  join TxOutput o on o.creating_txhash = t.txhash
 where (t.blknum, t.txindex, o.oindex) = @position
```

### 9. add checkpoint
`insert into Checkpoint values (@blknum, hash, eth_height)`

### 10. get exit data by utxo in checkpoint
Checkpoint isn't fully understood right now, however we expect that during checkpoint preparation we compute all proofs for utxo we might be interested to exit. TxOutput table has field `proof` just for this purpose.
