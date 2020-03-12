# Exit validation

This document describes the exit validation (processing) done by the Watcher in `ExitProcessor`.

## Definitions

* **scheduled finalization time** - a point in time when an exit will be able to process, see [docs/tesuji_blockchain_design.md#finalization-of-exits]
* **`exit_finality_margin`** - margin of the exit processor (in Ethereum blocks) - how many blocks to wait for finality of exit-related events
* **Child Chain exit recognition SLA** - a form of a Service Level Agreement - how fast will the child chain recognize newly stated exits and block spending of exiting utxos
* **`sla_margin`** - margin of the Child Chain exit recognition SLA (in Ethereum blocks).
This is a number of blocks after the start of an exit (or piggyback), indicating a period of time when a child chain still might include a transaction invalidating a previously valid exit, without violating the Child Chain exit recognition SLA.

## Notes on the Child Chain Server

This document focuses on the Watcher, but for completeness we give a quick run-down of the rules followed by the Child Chain Server, in terms of processing exits events from the root chain contract.

1. The Child Chain operator's objective is to pro-actively minimize the risk of chain becoming insecure or, in worst case scenario, insolvent.
The Child Chain becomes insolvent if any invalid exit gets finalized, which leads to loss of child chain funds.
2. To satisfy this objective:
    - the Child Chain server listens to every `ExitStarted` Root Chain event and immediately "spends" the exited utxo.
    - the Child Chain server listens to every `InFlightExitStarted` Root Chain event and immediately "spends" the exiting tx's **inputs**
    - the Child Chain server listens to every `InFlightExitPiggybacked` Root Chain event (on outputs) and immediately "spends" the piggybacked outputs - as long as the IFEing tx has been included in the chain and the output exists
  These rules block the user from spending an UTXO exiting this way or another, thus preventing exit invalidation.
  This immediacy is however limited; the server must process deposits before exits.
  Otherwise, an exit from a fresh deposit might be processed before that deposit (and deposits _must_ wait for finality on the root chain).

There are scenarios, when a race condition/reorg on the root chain might make the Child Chain Server block spending of a particular UTXO **too late**, regardless of the immediacy mentioned above.
This is acceptable as long as the delay doesn't exceed the `sla_margin`.

## Standard Exits

### Actions that the Watcher should prompt:
1. If an exit is known to be invalid it should be challenged (almost) immediately. The Watcher prompts by an `:invalid_exit` event.
2. If an exit is invalidated with a transaction submitted *before* `start_eth_height + sla_margin` it must be challenged (`:invalid_exit` event)
3. If an exit is invalidated with a transaction submitted *after* `start_eth_height + sla_margin` it must be challenged **AND** the Watcher prompts to exit. The Watcher prompts by both `:invalid_exit` and `:unchallenged_exit` events. Users should not deposit or spend
4. If an exit is invalid and remains unchallenged *after* `start_eth_height + sla_margin` it must be challenged **AND** the Watcher prompts to exit. The Watcher prompts by both `:invalid_exit` and `:unchallenged_exit` events. Users should not deposit or spend.
5. The `unchallenged_exit` event also covers the case where the invalid exit finalizes, causing an insolvent chain until [issue #1318 is solved](github.com/omisego/elixir-omg/issues/1318).

More on the [`unchallenged_exit` condition](#unchallenged-exit-condition).

The occurrence of the `unchallenged_exit` condition is checked for on every child chain block being synced.

All that takes as an assumption that:
  - the user's funds must be safe even if the user only syncs and validates the chain periodically (but not less frequently than required)
  - the user needs to have the ability to spend their UTXOs at any time, thereby requiring more stringent validity checking of exits

### Solution for above cases:
2. `ExitProcessor` pulls open exit requests from root chain contract logs, as soon as they're `exit_finality_margin` blocks old (~12 blocks)
3. For every open exit request run `State.utxo_exists?` method
    * if `true` -> noop,
    * if `false` -> emit `:invalid_exit` event prompts to challenge
    * if `false` and exit is older than `sla_margin` -> emit additionally an `:unchallenged_exit` event which promts mass exit
4. Spend UTXOs in `State` on exit finalization
    * if the spent UTXO is present at the moment, forget the exit from validation - valid finalization
    * if the spent UTXO is missing - keep on emitting `:unchallenged_exit` (until [issue #1318 is solved](github.com/omisego/elixir-omg/issues/1318)).
5. `ExitProcessor` recognizes exits that are (as seen at the tip of the root chain) already gone, when pulled from old logs.
This prevents spurious event raising during syncing.
This is the current behavior, to be substituted by a more verbose one in [#1318](github.com/omisego/elixir-omg/issues/1318)
6. Checking the validation of exits is user responsibility.
This is done by calling `/status.get` endpoint.

### `unchallenged_exit` condition

This section treats this particular condition in-depth and explains the rationale.

To reiterate, `unchallenged_exit` is raised and reported in the `byzantine_events` in `/status.get`'s response, whenever there is _any_ exit, which is invalid and old.
"Old" means that its respective challenge required _might be_ approaching scheduled finalization time, or just has been unchallenged for an unjustified amount of time.

The action to take, when such condition is detected is to _exit all utxos_ held on the child chain.
The rationale is that we suspect that the chain is imminent to become invalid, because some funds that shouldn't be exiting are being allowed to exit.
We do not wait until it's "too late" and report _post factum_ - if we did, our mass exit could end up having too low a priority.

Another thing to explain here is that the Watcher will **stop getting new child chain blocks** whenever it finds itself in an `unchallenged_exit` condition.
This stopping behavior is similar to as when an `invalid_block` condition is detected.
The reason for this is to:
 - protect the user from relying on a possibly corrupt or insecure state of the system (e.g. accepting funds that won't be exitable)
 - make the byzantine report loud and make the warning logged more visible
 - prevent a possible corruption of the internal state (this is more of an implementation detail, but worth to keep in mind), which could result if the exit finalized.

In short, if at any point when watcher realizes it's in the "unsafe world" it stops processing blocks.

An important thing to remember though, is that challenges keep on processing.
In particular, the root cause of the `unchallenged_exit` condition, **might be gone** at one point, because the invalid exit got challenged.
**In particular, it won't show up in the `byzantine_events` list, when queried from `/status.get`!**.
However, by design, the Watcher won't resume getting new blocks without a manual restart; the process of "coming back to validity" is not supported.
This behavior is driven by the notion that if things go this bad, it's game over, so yanking the watcher back into "safe world" automatically hasn't been considered,
for simplicity's sake and to avoid resuming when one shouldn't by error.

From the protocol point of view, the first moment `unchallenged_exit` is spotted, the user should have commenced their mass exit.
This is another way to put why resuming syncing is not currently supported.

### Things considered
1. We don't want to have any type of exit-related flags in `OMG.State`'s utxos
2. The reason to wait `exit_finality_margin` is to not have a situation, where due to a reorg, an exit is tracked and then vanishes.
If we didn't handle that it would grow old and at some point could raise prompts to mass exit (`:unchallenged_exit`).
An alternative is to always check the current status of every exit, before taking action, but that might create excessive load on the Ethereum RPC and be quite complex

## In-flight exits

All the above rules will apply analogically to in-flight exits, see [MoreVP](./morevp.md) for specs and introduction to in-flight exits.
Invalid attempts to do an in-flight related action prompt challenges.
Absence of challenges within the `sla_margin`, as well as invalid finalization, should result in client prompting to mass exit (to be implemented in [issue #1275](github.com/omisego/elixir-omg/issues/1275)).
`OMG.State` is modified on IFE finalization.
