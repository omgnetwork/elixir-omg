# Exit validation

NOTE:
* `M_SV` margin of slow validator
* `M_FV` margin of fast validator
* `SLA` service Level Agreement
* `FV` FastValidator
* `SV` SlowValidator
* `BG` BlockGetter

##### The purpose of having exit validators is to:
1. prevent user from loosing money
2. letting know user about byzantine child chain
3. preventing of having any type of flags in State's utxos
4. (optional) protect against loss in case of invalid exit finalization
5. notify and facilitate challenges and exits. 
6. notify receiver and let him decide about if the challenge is still required

##### Actions that the Watcher should prompt:
1. If an exit is known to be invalid it should be challenged immediately
2. If an exit is invalidated with a transaction submitted within an acceptable `M_SV` period it must be challenged
3. If an exit is invalidated with a transaction submitted after an acceptable `M_SV` period , watcher must prompt an exit
4. (optional) If a finalization of an invalid exit occur  without challenge , watcher must prompt an exit without guarantees
 
##### Cases for above actions:
1. The exit is processed after the tx, so it is known to be invalid from the start. Causes to emit an `:invalid_exit` event.
2. The exit is processed before the tx, but the tx is within `M_SV` period , so the child chain is valid. Causes to emit an `:invalid_exit` event.
3. The exit is processed before the tx, but tx is after `M_SV` period, so the child chain is byzantine. Causes to emit an `:invalid_block` event.
4. (optional) Continuation of cases (1) or (2) where the exit never get's challenged. Causes to emit an `:contract_underfunded` event, which is also a prompt to exit

##### Solution for above cases:F
1. `FV` validates exits immediately and if exit is invalid then emits an `:invalid_exit` event. Configured with `M_FV` set to zero.
2. `SV` validates exits after `M_SV` and spends the utxo in State. if exit is invalid then emits an `:invalid_exit` event
3. `BG` does what it usually does, so `:utxo_not_found` would cause to emit `:invalid_block` event.
4. (optional) `NewSuperService(NSS)` detects finalization of an invalid exit and prompt to exit the underfunded root chain contract

##### Alternative solution:
1. Drop idea of having `FV` and `SV`
2. Having a `ExitValidator` which periodically will be pulling open exit requests from root chain contract
3. For every open exit request run `State.utxo_exists?` method
    * if `true` -> noop, 
    * if `false` -> emit `:invalid_exit` event  which leads to challenge
    * if `false` and there is less than `SLA` time till finalization -> prompt exit
4. Spend utxos in `State` only on `:finalize_exits` event

note:
* Currently `Rootchain` contract does not have a functionality for pulling open exit requests. The potential solution 
for this for this could be a analyzing logs + `RootChainCoordinator`.