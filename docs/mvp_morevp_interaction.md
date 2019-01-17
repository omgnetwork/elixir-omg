MVP vs MoreVP
==

Since both MVP exit (aka standard exit aka SE) and MoreVP exit (aka in-flight exit aka IFE) provide an exit opportunity, it is possible to effectively double-spending. To prevent such possiblity, and to preserve the rule that honest owner can ignore IFE provided that he enjoys data availability, following scenarios are evaluated.

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
    NOTE: can do that even if I remembered `standardExitId(hash(tx), oindex)` on SE, because I am getting the input txs all over again in IFE

2. Mallory does SE on input, finalized -> Mallory submits IFE  
    => (IMPLEMENTED) contract: introduce `standardExitId(hash(tx), oindex)`, check if SE exists, if so treat IFE is "as if non-canonical" and can't be canonized; input is marked as finalized with regard to piggybacking. Add additional flag to IFE which will prevent it from taking part in canonicity game.

3. Mallory submits IFE -> Mallory does SE on input  
    => Alice: performs standard SE challenge using IFE tx as spend

4. Mallory does IFE, piggybacks input, waits for finalization -> Mallory submits SE on input  
    => same as (3.)

5. Mallory does SE on output -> Mallory submits IFE -> Mallory piggybacks output  
    => (IMPLEMENTED) contract: `standardExitId(hash(tx), oindex)`. This allows to find SE when PB is performed. Need to store utxo_pos in Exit struct during `startStandardExit`, though.  
    NOTE: costs: +20k on `startStandardExit`; low cost on PB check  
    NOTE: make revertable, so we can implement alt game solution later  
    => (alt) (if data availability) Alice: challenges piggyback with new challenge type  
    => (alt) (if no data avail) do nothing: IFE output exits, SE exits after all mass exits  
    NOTE: why can't we purely in contract (as in 7.) here? B/c "important" info (tx hash) is delivered too early and forgotten.  
    But if we do standardExitId(...) then ok  
    NOTE: as rule, we always block whatever is started later (piggyback here, SE in 8./9.)

6. Mallory does SE on output, waits for finalization -> Mallory submits IFE -> Mallory piggybacks output  
    => (IMPLEMENTED) contract: introduce `standardExitId(hash(tx), oindex)`; on PB compute SE id, check if it exists  
    => (alternative) exit game as in 5. Piggyback is challenged (take bond)

7. Mallory submits IFE -> Mallory does SE on output  
    => (IMPLEMENTED) contract: take tx from SE, find tx in IFEs, block future piggybacks on output  
    NOTE: +5k gas (after constantinople)

8. Mallory submits IFE -> Mallory does SE on output -> Mallory waits for SE finalization -> Mallory piggybacks  
   ! not possible

9. Mallory submits IFE -> Mallory piggybacks output -> Mallory does SE on output  
    => (IMPLEMENTED) contract: when SE happens, check for IFE & piggyback existence  
    NOTE: +18k gas on startSE

10. Mallory submits IFE -> Mallory piggybacks output -> Mallory waits for finalization -> Mallory does SE on output  
    ! same as (8.)

### Exploring `standardExitId(hash(tx), oindex)`
Q: What is that?  
A: Change the way `inFlightExitId` and `standardExitId` are computed, so both are a function of hash(tx).
This way whenever one type of exit comes in we can check if other type of exit was performed.

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
A: Number of outputs is known on both IFE and PB; single SLOAD per output?  

### Anatomy of exit id and priority value

Most significant bits first, priority value.

42 bits - timestamp (exitable_at); unix timestamp fits into 32 bits  
54 bits - blknum * 10^9 + txindex; to represent all utxo for 10 years we need only 54 bits  
8 bits - oindex; set to zero for in-flight tx  
1 bit - in-flight flag  
151 bit - tx hash

Anatomy of exit id (both in-flight and standard), most significant bits first:

8 bits - oindex; set to zero for in-flight tx  
1 bit - in-flight flag  
151 bit - tx hash
