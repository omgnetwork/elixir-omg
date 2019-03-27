# Exit validation

This document describes the exit validation (processing) done by the Watcher in `ExitProcessor`.
**NOTE** not all of this is implemented yet.

NOTE:
* `exit_finality_margin` margin exit processor (in Ethereum blocks)
* `SLA` Service Level Agreement
* `sla_margin` margin of service level agreement validation (in Ethereum blocks). This is a number of blocks prior to finalization, indicating a period of time that can affect the validity of an exit.

## Notes on the Child Chain Server

This document focuses on the Watcher.

For completeness we give a quick run-down of the rules followed by the Child Chain Server, in terms of processing exits sent on the root chain contract.

1. The Child Chain operator's objective is to pro-actively minimize the risk of chain becoming invalid.
The Child Chain will become invalid if any invalid exit gets finalized.
2. To satisfy this objective:
    - the Child Chain server listens to every `ExitStarted` Root Chain event and immediately "spends" the exited utxo.
    - the Child Chain server listens to every `InFlightExitStarted` Root Chain event and immediately "spends" the exiting tx's **inputs**
    - the Child Chain server listens to every `InFlightExitPiggybacked` Root Chain event (on outputs) and immediately "spends" the piggybacked outputs - as long as the IFEing tx has been included in the chain and the output exists
  These rules block the user from spending an UTXO exiting this way or another, thus preventing exit invalidation.
  This immediacy is however limited; the server must process deposits before exits.
  Otherwise, an exit from a fresh deposit might be processed before that deposit (and deposits _must_ wait for finality on the root chain).

There are scenarios, when a race condition/reorg on the root chain might make the Child Chain Server block spending of a particular UTXO **too late**, regardless of the immediacy mentioned above.
This is acceptable as long as the delay doesn't exceed `scheduled finalization time` minus the predetermined `sla_margin`.

## Standard Exits

### The purpose of having exit validation as a separate service is to:
1. proactively prevent the user from losing money by:
    - prohibiting the user from spending on a dangerous chain
    - trying to preempt underfunded chain situation, which would jeopardize user's funds
2. let the user know about byzantine child chain as soon as is reasonably possible
4. (optional) protect against loss in case of an invalid exit finalization
5. prevent spurious prompts to mass exit that might result from root chain reorgs, race conditions etc.

### Actions that the Watcher should prompt:
1. If an exit is known to be invalid it should be challenged (almost) immediately
2. If an exit is invalidated with a transaction submitted *before* `scheduled_finalization_time - sla_margin` it must be challenged
3. If an exit is invalidated with a transaction submitted *after* `scheduled_finalization_time - sla_margin` it must be challenged **AND** watcher must prompt an exit **AND** watcher must not allow spending and depositing
    - because our child chain implementation will never get close to this happening, so it is a symptom of a (subtle) hack attempt on the child chain server.
    By "subtle" we mean that it is a hack that counts on getting away with exit invalidation being submitted too late, rather than on just dropping a huge invalid UTXO and attempting to exit from that
4. If an exit is invalid and remains unchallenged within a short period of time (`sla_margin`) from its finalization, it must be challenged **AND** watcher must not allow spending and depositing, because:
    a. we are running too close to the minimum safety requirements
    b. Unchallenged exit creates a partial reserve situation and causes funds loss for some of users. There will be a loss of funds and it is not related to time.
    This can happen when an exit, a spend that invalidates that exit and an exit of that invalidating spend all coincide and are unchallenged.
5. (optional) If finalization of an invalid exit occurs, the watcher must prompt an exit without guarantees of recovery of funds

Conditions 3 and 4 can be represented jointly, by **continuous** (every child block) validation of the exits.
If any exit is invalid and its finalization is near, then actions listed under 3 and 4 should take place.

All that takes as an assumption that:
  - the user's funds must be safe even if the user only syncs and validates the chain periodically (but not less frequently than required)
  - the user needs to have the ability to spend their UTXOs at any time, thereby requiring more stringent validity checking of exits

### Example cases for above actions:
1. The exit is processed *after* the tx that invalidates it, so it is known to be invalid from the start. Causes an `:invalid_exit` event.
2. The exit is processed *before* the tx that invalidates it and the tx occurs *before* `finalization - sla_margin`, so the child chain is still valid.
Causes an `:invalid_exit` event.
3. The exit is processed *before* the tx that invalidates it, but the tx occurs *after* `finalization - sla_margin`, so the child chain is byzantine.
Causes an `:unchallenged_exit` event.
4. An invalid exit is still unchallenged after `finalization - sla_margin`, so the child chain is jeopardized.
Causes an `:unchallenged_exit` event.
5. (optional) Continuation of cases (1) or (2) where the exit never gets challenged and finalizes.
Causes an `:invalid_finalization` event.

### Solution for above cases:
2. `ExitProcessor` pulls open exit requests from root chain contract logs, as soon as they're `exit_finality_margin` blocks old (~12 blocks)
3. For every open exit request run `State.utxo_exists?` method
    * if `true` -> noop,
    * if `false` -> emit `:invalid_exit` event  which leads to challenge
    * if `false` and there is less than `sla_margin` time until finalization -> `:unchallenged_exit`
4. Spend utxos in `State` on exit finalization or challenging
5. `ExitProcessor` recognizes exits that are (as seen at the tip of the root chain) already gone, when pulled from old  logs.
This prevents spurious event raising during syncing.
6. Checking the validation of exits is user responsibility by calling `/status.get` endpoint.


### Things considered
1. We don't want to have any type of exit-related flags in `OMG.State`'s utxos
2. The reason to wait `exit_finality_margin` is to not have a situation, where due to a reorg, an exit is tracked and then vanishes.
If we didn't handle that it would grow old and at some point could raise prompts to mass exit (`:unchallenged_exit`).
An alternative is to always check the current status of every exit, before taking action, but that might create excessive load on `geth` and be quite complex

### Mandatory automatic challenging with a strategy + spend prohibition

The above notifications aren't enough to guarantee soundness of the chain.

By the power of defaults we should:
  - force the user running the Watcher to keep a (modestly) funded Ethereum account (`challenger`), that will be used to challenge **automatically** all of the invalid exits seen
  - do the automatic challenging according to some randomized strategy, that will ensure that the challenges won't burn each other
  - prohibit spending if the chain is approaching invalid exit finalization
  - prohibit spending also when there are valid exits, but the `challenger` address is underfunded

The ether for gas for challenges will be provided from that `challenger` account which holds a non-critical amount of eth, just for challenging - hence allowing the Watcher (or other automatic service) to operate with control over `challenger`'s private key.

In terms of "pay", as opposed to "provide ether for gas", the `challenger` is reimbursed from the exit bond being slashed.
**TODO** how to do this robustly?

To ensure the above works, challenges shouldn't involve a need to place large bonds nor should be required to be done from addresses holding funds.

### Relation to MoreVP exits

All the general rules will apply in the MoreVP world.
Invalid attempts to do an exiting action using MoreVP must excite challenges.
Absence of challenges within some period (like `sla_margin`) must result in client prompting to exit.
`State` will be modified on finalization, and if the finalization is invalid should `:invalid_finalization` and prompt exit.

## In-flight exits

With MoreVP, we need to handle another type of exit game, which is the in-flight exit game, as specced out [here](docs/morevp.md).

In terms of handling within the Watcher, similar principles will apply:
  - we gather and keep in `OMG.Watcher.ExitProcessor`'s persistent state the current state of in-flight txs and exits
  - we periodically check the validity of this state, emitting events and allowing for actions as necessary
  - we touch `OMG.State` only when the in-flight exit finalizes
  - if some invalid IFE or piggyback runs unchallenged for too long, it should be a prompt to exit (ala `:unchallenged_exit` above)

**[Diagram](https://docs.google.com/drawings/d/1UaAMZTJBbikTM0eFSbNM7ZVgi1HZrLTfwYCUvHGUaW0/edit?usp=sharing)** illustrates the flows described below (with the addition of handling on the Child Chain Server side for comparison).

**NOTES on the diagram**:
  - `ACTION` means both:
      - an event delivered to the user
      - the user should then be able to take some action on the root-chain

There are two rather independent flows in play:

### In-flight transaction tracking

This flow is about the user employing the MoreVP exit game to secure their own broadcast transactions.

This flow begins with transaction being broadcast via the Watcher.
Every such transaction is remembered and dubbed "in-flight".
Such in-flight txs, in case of any byzantine behavior by the child chain - one that would prompt an immediate exit, causes a prompt to start an in-flight exit.

**TODO** - in the first implementation, tracking of in-flight transactions isn't done in the Watcher but punted on the user.
The user should figure out how to exit which of their funds upon receiving a generic `byzantine_chain` event.

### In-flight exit tracking

This flow is about the user piggybacking (or not), challenging IFEs and responding to challenges related to IFEs that are **already started** on the root chain contract.

#### new IFEs, competitors, piggybacks

Any `InFlightExitStarted` should, after `exit_finality_margin`, cause the IFE to be tracked and tx added to something called `TxAppendix`.

Any competitor published should, after `exit_finality_margin`, be tracked and tx added to `TxAppendix`

Any piggyback done should, after `exit_finality_margin`, be taken into account.

#### finalization

Finalization behaves analogically to standard exits - finalization spends in `OMG.State` all utxos that actually exit **and existed in the child chain**.
These spends that fail cause a byzantine chain condition (`unchallenged_exit`)

#### "wait"

🕐 Periodically (same as with standard exits), `ExitProcessor` should:
  - find invalid piggybacks and do something
  - find non-canonical transactions that are seen as canonical in the root chain contract
  - find canonical transactions that are seen as non-canonical in the root chain contract

#### Checking if I should piggyback

Any IFE started might be one such that the user should piggyback onto.

This action should be prompted/enabled if all are satisfied:

 - an input or an output of the in-flight transaction submitted mentions the user as owner
 - for owned inputs - the in-flight transaction has inputs owned by others (which might have double-spent making the potentially tx non-canonical)
 - for owned outputs - the in-flight transaction has inputs included in a valid, seen block (otherwise these might be IFE done as part of a DDoS attack by the operator and have no chance in succeeding).
 Details:
 > If watcher does not perform such check, operator can use it as a part of his own DoS of Ethereum.
 By creating IFE with a tx: `{inputs: from_withhold_block, outputs: [A1, A2, A3, A4]}` operator can provoke four Alices to do a piggyback, amplifying it's own gas investment, creating a DDoS out of his own DoS.


(**NOTE** this will also occur if it is the very user that has started the IFE, see section [**In-flight transaction tracking**](./exit_validation.md#in-flight-transaction-tracking))

This happens on every new IFE detected.

#### `TxAppendix`

It is a tracked and persisted store of transactions that augments the transactions held in the child chain blocks.
The augmentation consist in that these transactions are taken into account, when the periodical processing of `ExitProcessor`.

For example consider this:
There are two competitor transactions that someone starts an IFE for.
Neither transaction appeared on chain, so we should store these transactions somewhere, to be able to figure out that we should and then how we should challenge such IFE (both transactions are not canonical).

`TxAppendix` will be a store of such transactions that have been published and are important, but haven't been included in any block, at least not at the time of publishing.

#### Fees

An interesting question is how are the fees implied by an IFEd transaction handled.

It depends on whether that transaction was included in the child chain:
  - if yes, the fees are eligible to be exited just the same, regardless of the IFE
  - if no, then the fees **aren't eligible to be exited**, and these funds are effectively burnt.
  An honest operator won't include these sums in the fees to be exited.
  Watchers will treat an attempt to include these sums in a fee exit as a byzantine condition.
