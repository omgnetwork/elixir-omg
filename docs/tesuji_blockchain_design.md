# Tesuji Plasma Blockchain Design

This document describes in detail the blockchain (consensus) design used by the first iteration of OmiseGO Plasma-based implementation.
The design is heavily based on [Minimal Viable Plasma design](https://ethresear.ch/t/minimal-viable-plasma/426), but incorporates several modifications.
The reader is assumed to have prior knowledge of Ethereum and familiarity with general ideas behind [Plasma](http://plasma.io).

## Overview

Tesuji Plasma's architecture allows users to take advantage of cheaper transactions with higher throughput without sacrificing security.
This is accomplished by allowing users to make transactions on a child chain which derives its security from a root chain.
By **child chain** we mean a blockchain that coalesces multiple transactions into a **child chain block** compacting them into a single, cheap transaction on a **root chain**.
In our case the root chain is the Ethereum blockchain.

### Key Features

These are the key features of the design, which might be seen as main deviations from the big picture Plasma, as outlined by the original Plasma paper:

1. Supports only transactions that transfer value between addresses (Multiple currencies: Eth + ERC20).
See **Transactions** section.
(The value transfer can take the form of an atomic swap - two currencies being exchanged in a single transaction.
See **Atomic Swap** section to see the usage of the atomic swap transaction. FIXME distill this section)
5. The network is a non-p2p, proof-of-authority network, i.e. child chain is centrally controlled by a designated, fixed Ethereum address (**child chain operator**), other participants (**users**) connect to the child chain server.
See **Child chain server** section
6. The Plasma construction employed is a single-tiered one, i.e. the child chain doesn't serve as a parent of any chain
7. There aren't facilities that allow cheap, coordinated mass exits

The essence of security and scalability features is the ability of users to perform the following scenario:

1. Deposit funds into a contract on the root chain
2. Cheaply make multiple transfers of funds deposited on the child chain
3. Exit any funds held on the child chain to reclaim them on the root chain, securely.
That is, every exit of funds held on the child chain must come with an attestation that the exit is justified.
The nature of that attestation will be clarified in following sections.

Since exits can be done regardless of the state of the PoA child chain, the funds held on the child chain and root chain might be treated _as equivalent_.
The condition here is that if anything goes wrong on the child chain, everyone must exit to the root chain.

It's worth noting that the Plasma architecture presumes root chain availability.

The consensus is driven by the following components:

1. **root chain contract** - responsible for securing the child chain:
    - holds funds deposited by other addresses (users)
    - tracks child chain block hashes submitted that account for the funds being moved on the child chain
    - manages secure exiting of funds, including exits of in-flight transactions
2. **child chain server** - responsible for creating and submitting blocks:
    - collects valid transactions that move funds on the child chain
    - submits child chain block hashes to the root chain contract
    - publishes child chain blocks' contents
3. **watcher** - responsible for validating the child chain and making sure the child chain consensus mechanism is working properly:
    - tracks the root chain contract, published blocks and transactions
    - reports any breach of consensus
    - (as additional service) collects and stores the account information required to use the child chain
    - (as additional service) provides a convenience API to access the child chain API and Ethereum.
    Such access is restricted only to times when the child chain is valid, in order to protect the user.

**NOTE** all cryptographic primitives used (signatures, hashes) are understood to be ones compatible with whatever EVM uses.

## Root chain contract

Note that the child chain and the root chain contract securing it manage funds using the UTXO model (see **Transactions** section).

### Deposits

Any Ethereum address may deposit Eth or ERC20 token into the root chain contract.
Such deposit increases the pool of funds held by the root chain contract and also signals to the child chain server, that the funds should be accessible on the child chain.
Depositing causes the deposited funds to be recognized as a single UTXO on the child chain.
Such UTXO can then be both spent on the child chain (provided that the child chain server follows consensus) or exited immediately on the root chain (regardless of whether child chain server follows consensus).

The mechanism of depositing consists in forming of a "pseudo-block" of the child chain, that contains a single transaction with the deposited funds as a new UTXO.

### Exits w/ exit challenges

Exits are the most important part of the root chain contract facilities, as they give the equivalence of funds sitting in the child chain vs funds on the root chain.

In principle, the exits must satisfy the following conditions:
- **E1**: only funds represented by UTXOs that were provably included in the child chain may be exited (see **Transactions** section).
This means that only funds that provably _existed_ may be exited.
- **E2**: attempts to exit funds, which have been provably spent on the child chain, must be thwarted and punished.
- **E3**: there must be a priority given to earlier UTXOs, for the event when the attacking child chain operator submits a block creating UTXOs dishonestly and attempts to exit these UTXOs.
It allows all UTXOs created before the dishonest UTXOs to exit first.
- **E4**: funds that are in-flight, i.e. locked up in a transaction, that might have or might have not been included in the child chain, must be able to exit on par with funds whose inclusion is known.

#### Submitting exit requests and challenging

**E1** and **E2** are satisfied by the following mechanism, depending on the inclusion:

**UTXOs, whose creating transaction is included in a known position in a child chain valid up to that point, use the _regular exit_:**

Any Ethereum address that proves possession of funds (UTXO) on the child chain, can submit a request to exit.
The proof consists in showing the transaction (containing the UTXO as output) and proving inclusion of the transaction in one of the submitted child chain blocks.

However, this isn't the full attestation required to be able to withdraw funds from the root chain contract.
The submitted (proven) exit request must still withstand a **challenge period** when it can be challenged by anyone who provides proof that the exited UTXO has been spent.
The proof of such double-spend is similar to the aforementioned proof of possession of funds (inclusion of a certain transaction).

Exit's challenge period counts from exit request submission till that exit's scheduled finalization time (see below).

A successful and timely exit challenge invalidates the exit.

**Funds that are in-flight, i.e. where inclusion of a transaction manipulating them is not known or inclusion is in an invalid chain, use the _in-flight exit_:**

Assuming that the in-flight transaction has inputs that had been outputs of a transaction included in a valid chain, such funds are recoverable using the [MoreVP protocol](morevp.md).

#### Finalization of exits

Finalizing an exit means releasing funds from the root chain contract to the exitor.
**E3** is satisfied by exit scheduling and priorities.

Exits finalize at their **Scheduled finalization time (`SFT`)**, which is:

```
SFT = max(exit_request_block.timestamp + MFP, utxo_submission_block.timestamp + MFP + REP)
```
for regular exits, and:

```
exitable_at = max(exit_request_block.timestamp + MFP, youngest_input_block.timestamp + MFP + REP)
```
for in-flight exits, see [MoreVP protocol](morevp.md) for details.

Deposits are protected against malicious operator by elevating their exit priority:
```
SFT = max(exit_request_block.timestamp + MFP, utxo_submission_block.timestamp + MFP)
```

In the above formulae:
- `exit_request_block` - root chain block, where the exit request is mined
- `utxo_submission_block` - root chain block, where the exiting UTXO was created in a child chain block
- `youngest_input_block` - root chain block, where the youngest input of the exiting transaction was created
- all exits must wait at least the **Minimum finalization period (`MFP`)**, to always have the challenge period
- fresh UTXOs exited must wait an additional **Required exit period (`REP`)**, counting from their submission to root chain contract.

> Example values of `MFP` and `REP` are 1 week and 1 week respectively, as in Minimal Viable Plasma.

Root chain contract allows to finalize exits which `SFT` had passed, always processing exits in ascending order of **exit priority**.
Exit priority has two keys:
- primary key is the `SFT`
- secondary key is the UTXO position (see **Transactions**)

#### Frequency of child chain validation

There are maximum periods of time a user can spend offline, without validating a particular aspect of the chain and exposing themselves to risk of fund loss:

 - must validate child chain every `REP` to have enough time to submit an exit request in case chain invalid
 - must validate exits every `MFP` to challenge invalid regular exits
 - must validate in-flight exits every `MFP/2` to challenge invalid actions in the in-flight exit protocol

Reassuming, to cover all the possible misbehavior of the network, the user must validate at rarest every `min(REP, MFP/2)`.

#### Example exit scenarios

The relation between `MFP` and `REP` is illustrated by the following:

- **Example 1**: `MFP = 1 day`, `REP = 2 day`
    - day 1 operator creates, includes, and starts to exit an invalid UTXO
    - day 3 user checks chain after being offline for 2 days (`REP`) and sees the invalid transaction, exits his old UTXO
    - day 4 both operator and user can exit (after `MFP`), but user's exit takes precedence based on `utxoPos`

### Block submissions

Only a designated address belonging to the child chain operator can submit blocks.
Every block submitted to the root chain contract compacts multiple child chain transactions.
Effectively, the block being submitted means that during exiting, ownership of funds (inclusion of transaction) can be now proven using a new child chain block hash.

### Network congestion

(TODO: **Note: This is currently being researched and discussed**)

The child chain will allow a maximum of N UTXOs at given time on the child chain.
N is bound by root chain's bandwidth limitations and is the maximum amount of UTXOs that can safely requested to exit, if the child chain becomes invalid.

Plasma assumes root chain network and block gas availability to start all users' exits in time.
If the network becomes too congested, we'll freeze time on the root chain contract until it becomes safe to operate again.

### Reorgs

Reorgs (block and transaction order changing) of the root chain can lead to spurious invalidity of the child chain.
For instance, without any protection, a deposit can be placed and then spent quickly on the child chain.
Everything is valid, if the submit block root chain transaction gets mined after the deposit (making the honest child chain to allow the spend).
However, if the order of these transactions gets reversed due to a reorg, the spend will appear before the deposit, rendering the child chain invalid.

We'll protect ourselves against reorgs by:
1. Only allowing deposits to be used on the child chain after N Ethereum Block confirmations (should be configurable).
This makes invalidating of the child chain by miners as expensive as we want it to be.
This rule will be built into the child chain itself, i.e. the root chain contract won't enforce this in any way.
2. Submitting blocks to the root chain contract is protected by account nonce mechanism.
Miner attempting to mine them in wrong order would produce incorrect Ethereum block.
3. Numbering of child chain blocks is independent of numbering of deposit blocks.
Disappearing deposit block will not invalidate numbering of child chain blocks.

## Child chain server

### Collecting transactions

The child chain server will collect transactions, executing the valid ones immediately.
The child chain will have **transactions per block limit** - an upper limit for the number of transactions that can go in a single child chain block.
If a submitted transaction would exceed that limit, it's going to be held off in a queue and scheduled for inclusion in the next block.
That queue would be prioritized by transaction fee value.
If there are too many transactions in the queue the ones with the lowest fees will be lost and must be resubmitted.

> Transaction per block limit is assumed to be 2^16, per Minimal Viable Plasma

### Submitting and propagating blocks

Every T amount of time the child chain will submit a block (in form of blocks' transactions merkle root hash) to root chain contract.

After the child chain has submitted a block to root chain contract it must share the block contents on watcher's request.
The watchers are responsible for taking in blocks and extracting whatever information they need from them (see **Watcher** section).

If the child chain operator submits an invalid block or withholds a submitted block (i.e. doesn't share the block contents) everyone must exit.

### Transactions

A transaction is spending existing UTXO(s) (inputs) and creating new UTXO(s) (outputs).
Generally, the transaction must specify the inputs being spent as well as owners of the outputs and their respective amounts.
The transaction must prove, that the spenders consent to their funds (inputs) being spent (by including signatures).

Each transaction can have up to 4 UTXOs as inputs, and create up to 4 UTXOs as outputs.

The transaction's fee is implicit (think bitcoin), i.e. surplus of the amount being inputted over the amount being outputted (`sumAmount(spent UTXOs) - sumAmount(created UTXOs) >= 0`) is the fee that the child chain operator is eligible to claim later.

A child chain transaction will have:
```
    [inpPos1, inpPos2, inpPos3, inpPos4,
    sig1, sig2,
    cur12, cur34,
    newOwner1, amount1,
    newOwner2, amount2,
    newOwner3, amount3,
    newOwner4, amount4]
```

- `inpPos` - specify the inputs to the transaction.
Every `inpPos` is an output's unique position, derived from child block number, transaction index within that block and output index.
Every such output must be unspent for the transaction to be valid.
`inpPos` might be zero if less than 4 inputs are required
- `sig` is a signature of all the other fields in a transaction, RLP-encoded and hashed.
A transaction can have up to two signatures even though it can have up to 4 inputs.
Any of the two signatures may prove any of the four inputs, all inputs must be proven.
This forces transactions with over two inputs to have multiple inputs with the same owner.
The decision to have at most two owners was made to increase simplicity because having more than two owners for  creating transactions is difficult in most real world cases.
This form of transaction is the minimal that allows for atomic swaps with change, see **Atomic Swaps** section.
`sig` may be 65 zero bytes if no signature is provided.
- `cur` denotes a currency being dealt with.
We have two currency fields to allow for atomic swaps to occur between two parties in a single transaction.
`cur12` specifies the currency for inputs/outputs 1 & 2, `cur34` - respectively.
`cur12` can be equal to `cur34` to allow "4-to-1" cheap merges of UTXOs.
- `newOwner` and `amount` specify a single output with the address of the new owner for a given amount

**NOTE** To create a valid transaction, a user needs to have access to positions of all the UTXOs that they own.

For a hands-on specs of transaction format see [here](docs/tesuji_tx_integration.md).

### Fees

#### Accepting fees by the child chain server

The child chain will have a configurable fixed min fee and will not accept any transactions below the fixed min fee.
The fixed min fee will be derived from the average of N different apis (see [here](https://developer.makerdao.com/feeds/) for more info) pinging the central server so that it stays up to date on the current prices.

#### Tracking and exiting fees

Child chain operator is eligible to exit the fees accumulated from the root chain contract.
See **Watcher** section for Watcher's role of tracking the correctness of fee exits.

## Watcher

The watcher is assumed to be run by the users, or taken differently, to be trusted by users of the child chain.
Proper functioning of the watcher is critical to the security of funds deposited.

The watcher is responsible for pinging the child chain server to ensure that everything is valid.
The watcher will watch the root chain contract for a `childBlock` log (a submission of a child chain block).
As soon as it receives a log it will ping the child chain for the full block and then make sure the block is valid and that it's root matches the child chain root submitted.

The watcher will check for the following conditions of chain invalidity.
Any of these make the watcher prompt for an exit of funds:

1. Invalid blocks:
    - With multiple transactions spending the same input.
    - Transactions spending an input spent in any prior block
    - Transactions spending exited inputs, if unchallenged or challenge failed or was too late
    - Transactions with deposits that haven't happened.
    - Transactions with invalid inputs.
    - Transactions with invalid signatures.
2. Fee exits by the child chain operator that take more fees than the operator has available to them.
It's the watchers job to check that the operator never exits more fees than they're due, because the funds to cover the exited fees are drawn from the same pool, where the deposited funds are.
In other words, if watchers overlook the child chain operator exiting too much fees, there might be not enough funds left in the root chain contract for them to exit.
3. Inability to acquire (for a long enough period of time) enough information to validate a child chain block that's been submitted to the root chain.

The watcher will check for the following conditions that (optionally) prompt for an exit challenge:

1. Exits during their challenge period referencing UTXOs that have already been spent on the child chain.
2. Invalid actions taken during the in-flight exit game, see [MoreVP protocol](morevp.md).

As soon as one watcher detects the child chain to be invalid, all others will as well and everyone with assets on the child chain will be notified to exit immediately.

### Storage facilities of the watcher (aka Account information)

Watcher takes on an additional responsibility: collecting and storing data relevant to secure handling of user's assets on the child chain:

1. UTXOs in possession of the address holding assets
2. Full transaction history (only if the Watcher is tasked with challenging)

## Exchange

This section outlines what the two flows of using the exchange sitting on top of Tesuji Plasma OmiseGO network could look like.
First (the baseline one) is a centralized exchange that takes custody over its user's funds.
The second one attempts to remove the need to give custody over user's funds to the exchange.

### Custodial exchange

An exchange will take custody of funds and then redistribute them.
The centralized exchange minimizes the amount of funds in custody and the amount of time they have custody to minimize risk of funds being lost, though this is not enforced on the child chain.
Custody is limited to the period between placing an order and order being matched and executed.
This is shorter, than in the situation where custody of funds is held between the deposit and withdrawal from the exchange done on the root chain.

Because the centralized exchange has custody they'll be able to support whatever order types and fee structures they want on Plasma MVP.

An example of how a user could interact with the centralized exchange would be:

1. Alice wants to trade Ether for OMG tokens and goes to an exchanges website.
1. There Alice is told that she has no tokens on the Plasma chain and is asked the currency and denomination she'd like to deposit.
1. She chooses 2 Ether, clicks deposit and is prompted to sign a metamask transaction.  
1. Alice watches her deposit transaction sink lower as more Ethereum blocks get mined on top of the deposit transaction block until sufficient block confirmations have been received from Ethereum (~12 blocks).
1. Alice is prompted to enter the parameters for her order; a price she'd like to trade at, the currency she'd like to trade to and from, and the quantity she'd like to trade.
Alice fills in 2 Ether, OMG and at .02 Ether per OMG and clicks submit.
1. Alice is then prompted to add the OMG Network custom rpc to metamask and sign her order transaction.
1. The exchanges website watches Alice's transaction get included in a child chain block that's submitted to the root chain, once this happens her order enters the orderbook and once it's conditions are met the order is filled.
1. Once the order is filled the exchange sends a transaction to Alice settling the order.
Alices receives her funds minus an exchange fee (exchange specific) and a plasma fee (set on Plasma chain) from the exchange.

Important:  In this example the exchange has custody between the time Alice sends the order and when Alice receives the settlement (or refund, in case the Alice cancels the order).

The centralized exchange will be responsible for creating well formed Plasma transactions for users to sign.

### Atomic swaps

(FIXME: section taken from the former "User flows" secion. Rethink/rewrite)
