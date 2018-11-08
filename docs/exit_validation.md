# Exit validation

This document describes the exit validation (processing) done by the Watcher in `ExitProcessor`.
**NOTE** not all of this is implemented yet.

NOTE:
* `M_FV` margin of fast validator
* `SLA` service Level Agreement
* `sla_margin` margin of service lever agreement validation
* `BG` BlockGetter

### The purpose of having exit validation as a separate service is to:
1. proactively prevent user from losing money
2. letting know user about byzantine child chain
3. preventing of having any type of flags in State's utxos
4. (optional) protect against loss in case of invalid exit finalization
5. prohibit user from spending on a dangerous chain

### Actions that the Watcher should prompt:
1. If an exit is known to be invalid it should be challenged immediately
2. If an exit is invalidated with a transaction submitted within an acceptable `sla_margin` period it must be challenged
3. If an exit is invalidated with a transaction submitted after an acceptable `sla_margin` period it must be challenged **AND** watcher must prompt an exit **AND** watcher must not allow spending and depositing
    - because our child chain implementation will never get close to this happening, so it is a symptom of a (subtle) hack of the child chain server.
    By "subtle" we mean that it is a hack that counts on getting away with exit invalidation being submitted too late, rather than on just dropping a huge invalid UTXO and attempting to exit from that
3. If an exit is invalid and unchallenged within a short period from it's finalization it must be challenged **AND** watcher must not allow spending and depositing
    - because otherwise, we are "tightly" following the minimum safety requirements
    - because otherwise, unchallenged exits may break the chain without honest holders having time to escape.
    This is the case when an exit, a spend invalidating it and exit of that coincide and are unchallenged.
4. (optional) If a finalization of an invalid exit occurs, watcher must prompt an exit without guarantees of recovery of funds

Conditions 3 and 4 can be represented jointly, by **continuous** (every child block) validation of the exits.
If any exit is invalid and its finalization is near, then actions listed under 3 and 4 should take place

All that takes as an assumption that:
  - the user's funds must be safe even if the user syncs and validates the chain periodically (but not less frequently than required)
  - user needs to have the ability to constantly spend their UTXOs, thereby requiring more stringent validity checking of exits

### Example cases for above actions:
1. The exit is processed after the tx, so it is known to be invalid from the start. Should emit an `:invalid_exit` event.
2. The exit is processed before the tx, but the tx is within `sla_margin` period, so the child chain is valid.
Causes an `:invalid_exit` event.
3. The exit is processed before the tx, but tx is after `sla_margin` period, so the child chain is byzantine.
Causes to emit an `:unchallenged_exit` event.
3. An exit is unchallenged within `sla_margin` period, so the child chain is jeopardized.
Causes to emit an `:unchallenged_exit` event.
4. (optional) Continuation of cases (1) or (2) where the exit never gets challenged and finalizes.
Causes to emit an `:invalid_finalization` event

### Solution for above cases:
2. `ExitProcessor` periodically pulls open exit requests from root chain contract
3. For every open exit request run `State.utxo_exists?` method
    * if `true` -> noop,
    * if `false` -> emit `:invalid_exit` event  which leads to challenge
    * if `false` and there is less than `sla_margin` time till finalization -> `:unchallenged_exit`
4. Spend utxos in `State` on exit finalization or challenging

### Mandatory automatic challenging with a strategy + spend prohibition

The above notifications aren't enough to guarantee soundness of the chain.

By the power of defaults we should:
  - force the user running the Watcher to keep a (modestly) funded Ethereum account (`challenger`), that will be used to challenge **automatically** all of the invalid exits seen
  - do the automatic challenging according to some randomized strategy, that will ensure that the challenges won't burn each other
  - prohibit spending if the chain is approaching invalid exit finalization
  - prohibit spending also when there are valid exits, but the `challenger` address is underfunded

To ensure the above works, challenges shouldn't involve a need to place large bonds nor should be required to be done from addresses holding funds.

### Relation to MoreVP exits

All the general rules will apply in the MoreVP world.
Invalid attempts to do an exiting action using MoreVP must excite challenges.
Absence of challenges within some period (like `sla_margin`) must result in client prompting to exit.
`State` will be modified on finalization, and if the finalization is invalid should `:invalid_finalization` and prompt exit.
