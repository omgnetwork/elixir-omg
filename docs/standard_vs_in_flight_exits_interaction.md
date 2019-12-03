# Standard vs In-flight Exits

Since both Standard exit (aka SE) and In-flight exit (aka IFE) provide an exit opportunity, it is possible to effectively double-spend. To prevent such possibility, whenever an output is finalized/withdrawn from the Plasma M(ore)VP framework, we flag the output as spent to the `PlasmaFramework`. For all exit game contract implementations, they should ignore those already-spent-outputs during `processExit`. In other words, though there can be multiple exits for the same output started concurrently, only the first that get processed can really exit the output. All the others would just not process and ignore the output if it is already flagged.

#### Glossary

* `IFE` - in-flight exit, active unless stated otherwise;
* `SE` - standard exit, active unless stated otherwise;
* `utxoPos` - output position inside Plasma chain. It is a combination of `blockNumber`, `txIndex` and `outputIndex` that shows where the output is located in the plasma chain;
* `OutputId` - global output identifier used in Plasma Framework, see description below;

#### OutputId
To be able to flag all finalized outputs, we would need a global schema for all outputs in our Plasma Framework. In current implementation, the global identifier for output is called `OutputId`. The schema is as followed:

1. For normal transaction outputs: `OutputId = hash(txBytes, outputIndex)`
2. For deposit transaction outputs: `OutputId = hash(txBytes, outputIndex, utxoPos)`

We add `utxoPos` as a salt for deposit transaction output because deposit transaction can potentially have same `txBytes` as another deposit transactions (see: [this issue](https://github.com/omisego/plasma-contracts/issues/80)), a naive `hash(txBytes, outputIndex)` would collide when `txBytes` are not unique. 

Also, there was discussion to abstract the output identifier to be more flexible, see [this note](https://github.com/omisego/plasma-contracts/issues/387). But as the first version of Plasma Framework, we decided to go forward with using `OutputId` as a global schema to flag all outputs.

#### Standard Exit scenario

A standard exit would only impacts an output. Thus, in the case of SE, only one output need to be considered. The `processExit` function for SE would check whether that output has been flagged or not before withdrawing the fund. Also, once processed, it would flag that output as spent in `PlasmaFramework`.

#### In-flight Exit scenario

An in-flight exit would impact all inputs and outputs of the in-flight exit transaction. If the IFE is canonical, it would exit the unchallenged piggybacked outputs. On the other hand, if the IFE is non-canonical, the unchallenged piggybacked inputs would be exited.

If any of the in-flight exit input is flagged during `processExit`, that exit would be considered as non-canonical (for more detail on the reasons, see: [this issue](https://github.com/omisego/plasma-contracts/issues/470)). Otherwise, the canonicity would be decided by the canonicity challenge game of the in-flight exit.

If the in-flight exit is considered non-canonical during processing, we flag only the exiting inputs as spent. In other words, if the input is piggybacked, unchallenged and not flagged as spent yet, it would be exited and then be flagged as spent to the `PlasmaFramework`.

On the other hand, if the in-flight exit is considered canonical, _all_ inputs plus the exiting outputs would be flagged. So if the output is piggybacked, unchallenged, and not flagged as spent yet, it would be exited and then be flagged as spent. Also all inputs would be flagged as well.

We flag all the inputs when canonical because the current interaction game would have some edge cases during data unavailability, operator can try to double spend via IFE. For more detail, see this issue: [here](https://github.com/omisego/plasma-contracts/issues/102). In short, current IFE interactive game design can potentially decide the canonicity differently during data unavailability to the real canonicity when there is full data availability. We mitigate this by using Kelvin's solution of flagging all inputs (see: [this comment](https://github.com/omisego/plasma-contracts/issues/102#issuecomment-495809967)). So even a mismatch canonicity happens, it cannot be double spent.


#### Previous design on SE <> IFE interaction

Previously we had a set of rules and action on the SE <> IFE interaction. It takes some time to evolve to the current one. See the original doc on `0.2` branch used for `RootChain.sol`: https://github.com/omisego/elixir-omg/blob/v0.2/docs/standard_vs_in_flight_exits_interaction.md. 

We end up change the mechanism heavily for two reasons:
1. Simplicity on the rule
2. The best solution to mitigate the IFE canonicity issue is to flag all inputs. So we need to flag output anyway.

Quite a lot of our current `id` schema comes from the previous doc, such as `exitId`.

Note that in previous design, `startInFlightExit` would auto challenge an existing standard exit. We removed such feature from the contract. As a result, watcher should add monitoring on such event when a standard exit can be challenged by an in-flight exit tx.

Also, see the discussion of changing the SE <> IFE interaction mechanism: https://github.com/omisego/plasma-contracts/issues/110

#### Current Implementation Of Payment Exit Game
For more details on our current implementation of Payment Exit Game: https://github.com/omisego/plasma-contracts/blob/master/plasma_framework/docs/design/payment-game-implementation-v1.md
