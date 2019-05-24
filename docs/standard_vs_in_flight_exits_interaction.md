# Standard vs In-flight Exits

Since both Standard exit (aka SE) and In-flight exit (aka IFE) provide an exit opportunity, it is possible to effectively double-spend.
To prevent such possibility, and to preserve the rule that honest owner can ignore IFE provided that he enjoys data availability, we need a set of rules.
We derive this set of rules by analyzing different scenarios, depending on order of actions taken by calling the MoreVP root chain contract.
Every scenario revolves around a conflict of exit actions (a double-spend attempt).
In each we explain possible ways of preventing the double spend.

#### Glossary

* `IFE` - in-flight exit, active unless stated otherwise;
* `SE` - standard exit, active unless stated otherwise;
* `SE on (in|out)put` - standard exit on utxo mentioned in in-flight exit as input or output;
* `->` denotes order of events;
* `=>` denotes proposed solution / action;
* `contract:` solution is contained to change in the contract;

### Possible scenarios

1. Mallory does SE on input -> Mallory submits IFE  
    => (IMPLEMENTED) contract: IFE challenges SE (~ +30k gas)  
    NOTE: can do that even if I remembered `standardExitId(txbytes, utxo_pos)` on SE, because I am getting the input txs all over again in IFE

2. Mallory does SE on input, finalized -> Mallory submits IFE  
    => (IMPLEMENTED) contract: introduce `standardExitId(txbytes, utxo_pos)`, check if SE exists, if so treat IFE is "as if non-canonical" and can't be canonized; input is marked as finalized with regard to piggybacking. Add additional flag to IFE which will prevent it from taking part in canonicity game.

3. Mallory submits IFE -> Mallory does SE on input  
    => Alice: performs standard SE challenge using IFE tx as spend

4. Mallory does IFE, piggybacks input, waits for finalization -> Mallory submits SE on input  
    => same as (3.)

5. Mallory does SE on output -> Mallory submits IFE -> Mallory piggybacks output  
    => (IMPLEMENTED) contract: introduce `standardExitId(txbytes, utxo_pos)`; on piggyback, compute SE id, if SE exits, block piggyback
    NOTE: `standardExitId(txbytes, utxo_pos)` allows to find SE when piggyback is performed. Need to store utxo_pos in Exit struct during `startStandardExit`, though.  
    NOTE: costs: +20k on `startStandardExit`; low cost on piggyback check  
    NOTE: make revertable, so we can implement alt game solution later  
    => (alt) (if data availability) Alice: challenges piggyback with new challenge type  
    => (alt) (if no data avail) do nothing: IFE output exits, SE exits after all mass exits  
    NOTE: why can't we purely in contract (as in 7.) here? B/c "important" info (tx bytes) is delivered too early and forgotten.  
    But if we do standardExitId(...) then ok  
    NOTE: as rule, we always block whatever is started later (piggyback here, SE in 8./9.)

6. Mallory does SE on output, waits for finalization -> Mallory submits IFE -> Mallory piggybacks output  
   ! same as 5; finalized SE leaves a trace

7. Mallory submits IFE -> Mallory does SE on output  
    => (IMPLEMENTED) contract: take tx from SE, find tx in IFEs, block future piggybacks on output  
    NOTE: +5k gas (after constantinople)

8. Mallory submits IFE -> Mallory does SE on output -> Mallory waits for SE finalization -> Mallory piggybacks  
   ! not possible, because IFE will finalize first because of use of "youngest input priority"
   ! is handled by 5/6 since piggyback will get blocked since SE exists anyway

9. Mallory submits IFE -> Mallory piggybacks output -> Mallory does SE on output  
    => (IMPLEMENTED) contract: when SE happens, use tx body to compute in-flight exit id and check for IFE & piggyback existence; block SE if piggyback exists or was finalized  
    NOTE: +18k gas on startSE

10. Mallory submits IFE -> Mallory piggybacks output -> Mallory waits for finalization -> Mallory does SE on output  
    ! same as (9.)

### Exploring `standardExitId(txbytes, utxo_pos)`
Many of solutions described above are possible only if there is a way to have one-to-one mapping between in-flight exits and standard exits.
To achieve that, we change the way `inFlightExitId` and `standardExitId` are computed,
so both are a function of tx_bytes (and optionally of tx_pos, [see](#Distinction-between-deposit-and-regular-transactions). 
This way whenever one type of exit comes in we can check if other type of exit was performed.


#### Distinction between deposit and regular transactions
In case the tx is a deposit, the `standardExitId` is a function of hash(tx concat tx_pos). 
This distinction was made as when one deposits the same amount twice (or more) the tx_bytes are the same, so without concatenating tx_pos, 
the exit ids would be the same and not unique for the similar deposits, therefore we concatenate the tx_bytes with the tx_pos of the deposit.
Unfortunately, we cannot `standardExitId` consistently for both regular txs and deposits, as we would loose one-to-one mapping between SE and IFE exit id, 
because IFE does not have a tx_pos.

For more on this topic please refer to [omisego/plasma-contracts#80](https://github.com/omisego/plasma-contracts/issues/80). 


#### Q&A

Q: Does this affect standard exit and standard challenge?  
A: Standard challenge addresses inputs by utxo_pos; this change breaks this link.  

Q: Can this be fixed?  
A1: We can store utxo_pos as one of the fields of Exit structure (+20k gas); challenger will deliver exit_id (negligible cost).  

Q: Could possibly drop utxo pos in favor of using txhash everywhere?  
A: No, utxo pos is critical for MVP.  

Q: Possible collision: inFlightExitId(hash(tx)) == standardExitId(hash(tx), 0)  
A: No collision, since it is used as key in different mappings.  

Q: Ordering in the priority queue?  
A: Priority is determined by most significant 64 bits out of 256, which are a timestamp anyway  

Q: Can operator exploit his ability to include tx multiple times combined with this change?  
A: I don't see a way to do it yet.  

Q: When IFE/piggyback on output is added, what is the cost of checking if standard exits were performed from output(s)?  
A: Number of outputs is known on both IFE and piggyback; single SLOAD per output?  

Q: Is there any issue/concern from having different exit id for deposit tx and regular tx?
A: The only problem is the fact that if we started an IFE from a deposit, we could not check whether someone tried to also SE the deposit. But this is not a problem since we cannot start an IFE from the deposit: `sum of inputs < sum of outputs`.
