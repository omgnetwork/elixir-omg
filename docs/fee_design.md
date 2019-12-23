# Fee Exit Design

This document describes the design for fee exits. It starts with the requirements, and then describes the basic fee mechanism within our Plasma M(ore)VP design. 

## Requirement

### Functional Requirement

1. The operator can exit fees to an address the operator owns.
2. Able to support fee exit for multiple transaction types where each transaction type can have different fee rules.
3. Support the initial fee rule for *payment* transaction, which is a fixed amount in cents per transaction.
4. More fee rules could be added later. Here are some examples:
   1. as a percentage of ETH gas. 
   2. as a percentage of notional (aka transaction dollar amount).
   3. fixed token price, floating with USD or other fiat.

### Non-functional Requirement
1. A Fee exit does not take more time than a normal exit to process.
2. A Fee exit can batch-exit multiple fees collected in different transactions.

### Out of Scope
The fee rules are enforced and implemented only on the child chain. While a POA Plasma network gives the operator the ability to censor transactions, users are protected by the Watcher which would report misbehaving operators that try to exit more fees than allowed in a recorded transaction.

## General fee mechanism design

### High level description

Child chain operators implement the format and rules for fees on a transaction, not the contracts. This is the case as long as the Plasma network runs as a POA.

The transaction fee is implied for a *payment* transaction. It is the difference of the sum of inputs and the sum of outputs. For instance, if the sum of inputs is 10 ETH and sum of outputs is 9.9 Eth, the 0.1 Eth difference would be the transaction fee.

To exit fees, an operator puts a special fee transaction into a plasma chain block. This allows the operator to spend the transaction fee output as a Payment transaction. By leveraging MoreVP, we only need a contract to represent the fee transaction type and can use the pre-existing exit game contract.

A fee transaction is unique from a normal transaction in that:

1. It does not need to consume any inputs. As the fee is implied (at least for the *payment* transactions), there is no output that consumes an input.
2. The verification of the fee transaction relies on Child Chain and Watcher only. 

Since the smart contracts do not verify the fee transaction, the Plasma M(ore)VP security relies on the Watcher to check that the included fee transactions are following the rules correctly. If an invalid fee transaction is mined, the Watcher will consider the operator as having gone rogue, and inform the users to mass exit the network.

This decoupling of fee rule from smart contract gives the operator a more fine-tuned control on updating the fee rules. See the following paragraph for fee rule changes.

### Fee rules upgrade/change

The fee rules are not implemented in the smart contracts but by the Child Chain, which sets the fee rules, and the Watcher, which informs users about the fee rules. Also, the fee transaction verification part is not bound to the logic of the fee rules. Fee rules come into force at the time the Child Chain processes transactions. A transaction not following the fee rules is rejected. Find more details on transaction verification in the design section.

As a result, fee rules updates are done by changing the logic of how the Child Chain service would accept/reject an incoming transaction and how Watcher/wallet update the logic to follow the new fee rule when generating transaction.

### Fee for new transaction type

In order to allow fees for a new transaction type, one would need to define how the fee is collected in the transaction type. We would flavor the fee to be always collected in an implicit way as it has already been decided to collect fee implicitly for *payment* transactions. To collect fees explicitly, the exit game contract of such transaction type might need to make sure the fees are exited via the standard fee exit mechanism instead of directly exiting with the explicit fee transaction output.

Once the way to collect fee is designed and defined, whenever there is a new transaction coming in, the Child Chain and Watcher should add the fee amount to the storage that records the sum of fee.

### Fee rule change within a transaction type

The Child chain service (the operator) needs to provide the fee rules to its clients. Clients can pass in the essential information such as address, token, transaction type, etc., and then the Child Chain can accept transactions that pay sufficient fees.

This gives the operator the ability to update fees in a traditional SaaS way. The operator can adjust fee rules at anytime with flexible control. It can be upgraded with a feature flag or via A/B testing.

## Chosen Design: Generate fee transactions to summarize the fees of each block

The design proposes that the Child Chain service automatically generates fee transactions at the end of each block. The Child Chain and Watcher perform the fee transaction verifications at the block level. A block, apart from the existing transaction verification logic, is valid if:

1. All fee transactions are included after all other types of transactions in that block. 
1. A fee transaction's output is the sum of the fees paid in a particular token by all transactions in that block.
1. There must be at most one fee transaction for a token per block.
1. There can be at most one fee transaction type per block block. (PS. as we extend the Plasma Framework, there can potentially be multiple transaction types that all count as "fee tx type")

Since the transactions are automatically generated from the Child Chain service, there is no need to do an authentication check. Inclusion of the fee transactions are optional, however fees collected in omitted blocks are lost to claim.

### Transaction design

The transaction would be of the following format:

```
        {
                txType: xxx,
                inputs: [],
                outputs: [],
                nonce: xxx,
                metaData: xxx,
        }
```

The list of inputs for fee transactions is empty, and the list of outputs only contains one output.

This output follows the fungible token output format, which can be spent as an input for a *payment* transaction.

```
        {
                outputType: xxx,
                amount: xxx,
                outputGuard: xxx,
                token: xxx,
        }
```
To represent fees for multiple tokens, one would need to generate multiple fee transactions.

The last field, `nonce`, would be computed via `hash(blockNum, token)`. `blockNum` is the block number that the fee transaction is mined to. `token` is the token that is claimed in the fee transaction output. This combination promises the `nonce` to be unique, and thus promises the fee transaction to be unique.

Since this fee transaction would have a specific transaction type (and also its outputs would have unique output types), we don’t need to worry about other transaction types that use the same mechanism (block number + token) to ensure uniqueness. Even if another transaction type, for instance, collides with the same outputs in the same block, they would end up with different transaction hash due to the transaction type difference. Transaction uniqueness is granted.

### Fee transaction type extension

The current Plasma Framework design is immutable on the ability of spending an output type in another transaction type once the contracts have been deployed. So let's say we have *payment* v1 that can spend the fee claiming output. When we extend the framework with *payment* v2, we would need another fee output type that is able to be spent in *payment* v2. As a result, we would need fee transaction type 2 as well during the extension. (As only new transaction type can create new output type)

Given this, the block verification should limit the block to be existing with a singe fee transaction type per block for simplicity. No matter which fee transaction types (1 or 2), it should calculate the fee balance of all transaction within the block. The only difference is how the output can be spent.

Child chain and Watcher could even further deprecate old fee transaction types afterward if not needed anymore. The logic change could be done by upgrading Child Chain service and Watcher together.

## Adding the fee exit feature to the Plasma Framework

This section will discuss how we can add the fee exit feature to our Plasma Framework using the chosen design, assuming we are launching the network without fee exit feature at the beginning.

Since the network would first be running with a *payment* transaction type which does not support having fee transaction type as input, to enable spending fee transaction into *payment* transaction, we would need a *payment* transaction v2 for that.

As a result, a high level steps of adding fee exit feature would be:

1. Implement the contracts to enable spending Fee transaction in *payment* transaction V2
2. Implement the Child Chain and Watcher logic to support new transaction types: fee transaction type and *payment* V2. Need to be able to check the correctness of the transactions, including special logic for fee transaction and the changes of block verification logics.
3. Implement Child Chain to automatically generate fee transactions within each block.
4. Makes sure that clients update to new Watchers
5. Could turn on the auto fee generation feature once all clients update to the new Watcher
6. Deploy the *paymentExitGame* for *payment* transaction v2 that has the ability to spend the fee transaction
7. (Optional) update deposit verifier to use *payment* transaction v2 directly
8. Wait 3 weeks for the new ExitGame contract to take effect
9. Spend fee transaction in *payment* transaction v2 and exit.

## Reference

* Tetsuji blockchain fee design: https://github.com/omisego/elixir-omg/blob/master/docs/tesuji_blockchain_design.md#fees
* Scope of Five Guys
* Fee exit high level discussion: https://github.com/omisego/plasma-contracts/issues/165

## FAQ

Q1: Is it possible for the operator to start collecting fees now, but defer adding the new fee-exit ALD to some time in the future? 

> Yes, it should be possible in the abandoned design. But be aware pre-collecting fee meanings we would need to put extra effort to migrate DB for fee feature during production. For instance, we would need to calculate the sum of fees while accepting new transactions, which might impact sum of fees too.

> In the chosen design, we can defer the fee-exit feature to the future but we would lose all pre-collected fees.

Q2: How often does a fee exit get called?

> This is for the operator to decide. We probably want to do this based upon finance requirements and risk management.

Q3: Since smart contracts do not check the fee logic, how do we handle in-flight exits that do not follow the fee rules?

> To be clear, it is about in-flight exit on other transaction types that are using MoreVP protocol instead of MVP, as in-flight exits are not possible for fee transactions. For other in-flight exit transactions, our current implementation would flag the inputs as spent directly. Those transactions would be overpaying on Ethereuem (assuming the gas to start the in-flight exit is larger than the fee we charge).

> In the future, we are planning to include the IFE transaction into the block if not already there. We might only include the transactions that follows the fee rules to a block. If an IFE occurs that does not follow the fee rules, it can still be a valid in-flight exit and be processed.

> See: https://github.com/omisego/elixir-omg/issues/994

Q4: Should we collect fees when spending the fee transaction's output to a *payment* transaction?

> To keep the transaction processing code simple, and in order not to introduce artificial code, we can treat this *payment* transaction the same as any *payment* transaction which is spending regular inputs. Therefore, when *payment* transaction will consolidate several fee-outputs it will be fee-free as a merge-transaction. Otherwise, a fee needs to be paid, which will be collectable by another transaction.

Q5: How should excessive fees paid be handled?

> They should be collected/exited normally, thereby decoupling fee requirements from fee collection. We can add some sanity checks on client software to avoid excessive fees.

Q6: Can we do 4 fee utxos as input (to *payment* transaction) and one *payment* utxo as output?

> Yes. As each block would generate a new fee utxo, we, as the operator, would like to continuously merge all fee utxos to single *payment* UTXO.
