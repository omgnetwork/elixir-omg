# More Viable Plasma

This document is based on the original [More Viable Plasma post](https://ethresear.ch/t/more-viable-plasma/2160/49) on ethresearch.
This document has been moved from the document created in [the research repo](https://github.com/omgnetwork/research/pull/44).
See there for the original work and discussion done on this design.

## Introduction

[Minimal Viable Plasma](https://ethresear.ch/t/minimal-viable-plasma/426) (“Plasma MVP”) describes a simple specification for a UTXO-based Plasma chain.
A key component of the Plasma MVP design is a protocol for “exits,” whereby a user may withdraw back to the root chain any funds available to them on the Plasma chain.
The protocol presented in the MVP specification requires users sign two signatures for every transaction.
Concerns over the poor user experience presented by this requirement motivated the search for an alternative exit protocol.

In this document, we describe More Viable Plasma (“MoreVP”), a modification to the Plasma MVP exit protocol that removes the need for a second signature and generally improves user experience.
The MoreVP exit protocol ensures the security of assets for clients correctly following the protocol.
We initially present the most basic form of the MoreVP protocol and provide intuition towards its correctness.
We also formalize certain requirements for Plasma MVP exit protocols and provide a proof that this protocol satisfies these requirements in the appendix.

An optimized version of the protocol is presented to account for restrictions of the Ethereum Virtual Machine.
We further optimize on the observation that the MoreVP exit protocol is only necessary for transactions that are in-flight when a Plasma chain becomes byzantine.

We note the existence of certain attack vectors in the protocol, but find that most of these vectors can be largely mitigated and isolated to a relatively small attack surface.
These attack vectors and their mitigations are described in detail.
Although we conclude that the design is safe under certain reasonable assumptions about user behavior, some points are highlighted and earmarked for future consideration.

Overall, we find that the MoreVP exit protocol is a significant improvement over the original Plasma MVP exit protocol.
We can further combine several optimizations to enhance user experience and reduce costs for users.
Future work will focus on decreasing implementation complexity of the design and minimizing contract gas usage.


## Basic Mechanism

In this section, we specify the basic MoreVP exit mechanism and give an intuitive argument toward its correctness.
A formal treatment of the protocol is presented in the appendix.


### Definitions

#### Deposit

A deposit creates a new output on the Plasma chain.
Although deposits are typically represented as transactions that spend some "special" input, we do not allow deposits to exit via the MoreVP exit protocol.
Instead, deposits can be safely exited with the Plasma MVP exit protocol.


#### Spend Transaction

A spend transaction is any transaction that spends a UTXO already present on the Plasma chain.


#### In-flight Transaction

A transaction is considered to be “in-flight” if it has been broadcast but has not yet been included in the Plasma chain.
A transaction may be in-flight from the perspective of an individual user if that user does not have access to the block in which the transaction is included.


#### Competing Transaction, Competitors

Two transactions are “competing” if they share at least one input.
The “competitors” to a transaction is the set of all transactions that are competing with the transaction in question, including the transaction itself.


#### Canonical Transaction

A transaction is “canonical” if none of its inputs were previously spent in any other transaction, i.e. that the transaction is the oldest among all its competitors.
The definition of “previously spent” depends on whether or not the transaction in question is included in the Plasma chain.

The position of a transaction in the chain is determined by the tuple (block number, transaction index).
If the transaction was included in the chain, an input to that transaction would be considered previously spent if another transaction also spending the input was included in the chain *before* the transaction in question, decided by transaction position.
If the transaction was not included in the chain, an input to that transaction would be considered previously spent if another transaction also spending the input is *known to exist*.

Note that in this second case it’s unimportant whether or not the other transaction is included in the chain.
If the other transaction is included in the chain, then the other transaction is clearly included before the transaction in question.
If the other transaction is not included in the chain, then we can’t tell which transaction “came first” and therefore simply say that neither is canonical.


#### Exitable Transaction

A spend transaction can be called “exitable” if the transaction is correctly formed (e.g. more input value than output value, inputs older than outputs, proper structure) and is properly signed by the owners of the transaction’s inputs.
If a transaction is “exitable,” then a user may attempt to start an exit that references the transaction.


#### Valid Transaction

A spend transaction is “valid” if and only if it is exitable, canonical, and only stems from valid transactions (i.e. all transactions in the history are also valid transactions).
Note that a transaction would therefore be considered invalid if even a single invalid transaction is present in its history.
An exitable transaction is not necessarily a valid transaction, but all valid transactions are, by definition, exitable.
Our exit mechanism ensures that all outputs created by valid transactions can process before any output created by an invalid transaction.


### Desired Exit Mechanism

The MoreVP exit protocol allows the owners of both inputs and outputs to transactions to attempt an exit.
We want to design a mechanism that allows inputs and outputs to be withdrawn under the following conditions.

The owner of an input `in` to a transaction `tx` must prove that:
1. `tx` is exitable.
2. `tx` is non-canonical.
3. `in` is not spent in any transaction other than `tx`.

The owner of an output `out` to a transaction `tx` must prove that:
1. `tx` is exitable.
2. `tx` is canonical.
3. `out` is not spent.

Because a transaction either is or is not canonical, only the transaction's inputs or outputs, and not both, may exit.


#### Priority

The above game correctly selects the inputs or outputs that are eligible to exit.
However, invalid transactions can still be exitable.
We therefore need to enforce an ordering on exits to ensure that all outputs created by valid transactions will be paid out before any output created by an invalid transaction.
We do this by ordering every exit by the position of the *youngest input* to the transaction referenced in each exit, regardless of whether an input or an output is being exited.


## Exit Protocol

### Motivation

The basic exit mechanism described above guarantees that correctly behaving users will always be able to withdraw any funds they hold on the Plasma chain.
However, we avoided describing how the users actually prove the statements they’re required to prove.
This section presents a more detailed specification for the exit protocol.
The MoreVP mechanism is designed to be deployed to Ethereum and, as a result, some particulars of this specification take into account limitations of the EVM.

Additionally, it's important to note that the MoreVP exit protocol is not necessary in all cases.
We can use the Plasma MVP exit protocol without confirmation signatures for any transaction included before an invalid (or, in the case of withheld blocks, potentially invalid) transaction.
We therefore only need to make use of the MoreVP protocol for the set transactions that are in-flight when a Plasma chain becomes byzantine.

The MoreVP protocol guarantees that if transaction is exitable then either the unspent inputs or unspent outputs can be withdrawn.
Whether the inputs or outputs can be withdrawn depends on if the transaction is canonical.
However, in the particular situation in which MoreVP exits are required, users may not be aware that an in-flight transaction is actually non-canonical.
This can occur if the owner of an input to an in-flight transaction is malicious and has signed a second transaction spending the same input.

To account for this problem, we allow exits to be ambiguous about canonicity.
Users can start MoreVP exits with the *assumption* that the referenced transaction is canonical.
Other owners of inputs or outputs to the transaction can then “piggyback" the exit.
We add cryptoeconomic mechanisms that determine whether the transaction is canonical and which of the inputs or outputs are unspent.
The end result is that we can correctly determine which inputs or outputs should be paid out.


### MoreVP Exit Protocol Specification

#### Timeline

The MoreVP exit protocol makes use of a “challenge-response” mechanism, whereby users can submit a challenge but are subject to a response that invalidates the challenge.
To give users enough time to respond to a challenge, the exit process is split into two “periods.” When challenges are subject to a response, we require that the challenges be submitted before the end of the first exit period and that responses be submitted before the end of the second.
We define each period to have a length of half the minimum finalization period (`MFP`).
Currently, `MFP` is set to 7 days, so each period has a length of 3.5 days.
Watchers must validate the chain at least once every period (`MFP/2`).


#### Starting the Exit


Any user may initiate an exit by presenting a spend transaction and proving that the transaction is exitable.
The user must submit a bond, `exit bond`, for starting this action.
This bond is later used to cover the cost for other users to publish statements about the canonicity of the transaction in question.

We provide several possible mechanisms that allow a user to prove a transaction is exitable.
Two ways in which spend transactions can be proven exitable are as follows:
1. The user may present `tx` along with each of the `input_tx1, input_tx2, ... , input_txn` that created the inputs to the transaction, a Merkle proof of inclusion for each `input_tx`, and a signature over `tx` from the `newowner` of each `input_tx`.
The contract can then validate that these transactions are the correct ones, that they were included in the chain, that the signatures are correct, and that the exiting transaction is correctly formed.
This proves the exitability of the transaction.
2. The user may present the transaction along signatures the user claims to be valid.
The contract can validate that the exiting transaction is correctly formed.
Another user can challenge one of these signatures by presenting some transaction that created an input such that the true input owner did not sign the signature.
In this case, the exit would be blocked entirely and the challenging user would receive `exit bond`.

Option (1) (chosen in the implementation) checks that a transaction is exitable when the exit is started.
This has lower communication cost and complexity but higher up-front gas cost.
This option also ensures that only a single exit on any given transaction can exist at any point in time.
Option (2) allows a user to assert that a transaction is exitable, but leaves the proof to a challenge-response game.
This is cheaper up-front but adds complexity.
This option must permit multiple exits on the same transaction, as some exits may provide invalid signatures.

<!-- TODO: Groom this section once we decide on (1) or (2) -->

These are not the only possible mechanisms that prove a transaction is exitable.
There may be further ways to optimize these two options.

We still need to provide a deterministic ordering of exits by some priority.
MoreVP exits are given a priority based on the position in the Plasma chain of the most recently included (youngest) input to that transaction.
Unlike the MVP protocol, we give each input and output to a transaction the same priority.
This should be implemented by inserting a single “exit” object into a priority queue of exits and tracking a list of inputs or outputs to be paid out once the exit is processed.


#### Proving Canonicity

Whether unspent inputs or unspent outputs are paid out in an exit depends on the canonicity of the referenced transaction, independent of any piggybacking by other users.
Unfortunately it’s too expensive to directly prove that a transaction is or is not canonical.
Instead, we assume that the referenced transaction is canonical by default and allow a series of challenges and responses to determine the true canonicity of the transaction.

The process of determining canonicity involves a challenge-response game.
In the first period of the exit, any user may reveal a competing transaction that potentially makes the exiting transaction non-canonical.
This competing transaction must be exitable and must share an input with the exiting transaction, but does not have to be included in the Plasma chain.
Multiple competing transactions can be revealed during this period, but only the oldest presented transaction is considered for the purposes of a response.

If any transactions have been presented during the first period, any other user can respond to the challenge by proving that the exiting transaction is actually included in the chain before the oldest presented competing transaction.
If this response is given before the end of the second period, then the exiting transaction is determined to be canonical and the responder receives the `exit bond` placed by the user who started the exit.
Otherwise, the exiting transaction is determined to be non-canonical and the challenger receives `exit bond`.

Note that this challenge means it’s possible for an honest user to lose `exit bond` as they might not be aware their transaction is non-canonical.
We address this attack vector and several mitigations in detail later.

It might also be the case that in-flight exit is opened where some of the inputs where referenced in standard exit and those standard exits were finalized.
In such case in-flight exit is flagged as non-canonical and further canonicity game can't change its status.

<!-- TODO: Include image of canonicity "state machine" -->


#### Piggybacking an Exit

As noted earlier, it’s possible that some participants in a transaction may not be aware that the transaction is non-canonical.
Owners of both inputs and outputs to a transaction may want to start an exit in the case that they would receive the funds from the exit.
However, we want to avoid the gas cost of repeatedly publishing and proving statements about the same transaction.
We therefore allow owners of inputs or outputs to a transaction to piggyback an existing exit that references the transaction.

Users must piggyback an exit within the first period.
To piggyback an exit, an input or output owner places a bond, `piggyback bond`.
This bond is used to cover the cost of challenges that show the input or output is spent.
A successful challenge blocks the specified input or output from exiting.
These challenges must be presented before the end of the second period.

Note that it isn’t mandatory to piggyback an exit.
Users who choose not to piggyback an exit are choosing not to attempt a withdrawal of their funds.
If the chain is byzantine, not piggybacking could potentially mean loss of funds.


#### Processing Exits

An exit can be processed after the second period.
If the referenced transaction was determined to be canonical, all piggybacked outputs still unchallenged are paid out.
If the referenced transaction was determined to be non-canonical, all piggybacked inputs still unchallenged are paid out.
Any inputs or outputs paid out should be saved in the contract so that any future exit referencing the same inputs or outputs can be challenged.


#### Combining with Plasma MVP Exit Protocol

The MoreVP protocol can be combined with the Plasma MVP protocol in a way that simultaneously preserves the integrity of exits and minimizes gas cost.
Although the two protocols use different determinations for exit priority, total ordering on exits is still needed.
Therefore, every exit, no matter the protocol used, must be included in the same priority queue for processing.
Honest user which enjoys data availability should be able to ignore in-flight exits that involve their outputs.
Owners of outputs on the Plasma chain should be able to start an exit via either mechanism, but not both.
To guarantee that money can't be double-spend via those two mechanisms, two approaches are possible.

##### Chosen solution
This approach minimizes complexity of interactive games while negatively affecting gas cost of a happy path.
Contract needs to check if other type of exit exists for particular output when standard exit is being submitted and it checks if standard exit is in progress / was finalized when in-flight exit is being added.
In first case new exit is blocked.
In second case - in-flight exit is marked as one which can be exited only from inputs, and problematic inputs are marked as spent for piggybacking purposes.
To make such checks possible, both types of exits need to use transaction hash as an exit id.
No additional interactive games arise from the fact of coexistence of MVP and MoreVP protocols.

##### Alternative solution, to be implemented later
To reduce gas costs for honest participants, new types of challenges needs to be introduced.
Piggybacks on outputs should be challenged by standard exits and vice-versa.
Standard exits on UTXO seen as the input of a in-flight tx exit can be challenged using tx body.
Canonicity of in-flight exit can be removed by pointing contract to finalized standard exit from in-flight exit inputs, marking particular input as spent.

For details, [see here](./standard_vs_in_flight_exits_interaction.md).



## Alice-Bob Scenarios

### Alice & Bob are honest and cooperating:

1. Alice spends `UTXO1` in `TX1` to Bob, creating `UTXO2`.
2. `TX1` is in-flight.
3. Operator begins withholding blocks while `TX1` is still in-flight.
Neither Alice nor Bob know if the transaction has been included in a block.
4. Someone with access to `TX1` (Alice, Bob, or otherwise) starts an exit referencing `TX1` and places `exit bond`.
5. Bob piggybacks onto the exit and places `piggyback bond`.
6. Alice is honest, so she hasn’t spent `UTXO1` in any transaction other than `TX1`.
7. After period 2, Bob receives the value of `UTXO2`.
All bonds are refunded.


### Mallory tries to exit a spent output:

1. Alice spends `UTXO1` in `TX1` to Mallory, creating `UTXO2`.
2. `TX1` is included in block `N`.
3. Mallory spends `UTXO2` in `TX2`.
4. Mallory starts an exit referencing `TX1` and places `exit bond`.
5. Mallory piggybacks onto the exit and places `piggyback bond`.
6. In period 2, someone reveals `TX2` spending `UTXO2`.
This challenger receives Mallory’s `piggyback bond`.
7. Alice is honest, so she hasn’t spent `UTXO1` in any transaction other than `TX1`.
8. After period 2, Mallory’s `exit bond` is refunded, no one exits any UTXOs.


### Mallory double spends her input:

1. Mallory spends `UTXO1` in `TX1` to Bob, creating `UTXO2`.
2. `TX1` is in-flight.
3. Operator begins withholding blocks while `TX1` is still in-flight.
Neither Mallory nor Bob know if the transaction has been included in a block.
4. Mallory spends `UTXO1` in `TX2`.
5. `TX2` is included in a withheld block.
`TX1` is not included in a block.
6. Bob starts an exit referencing `TX1` and places `exit bond`.
7. Bob piggybacks onto the exit and places `piggyback bond`.
8. In period 1, someone challenges the canonicity of `TX1` by revealing `TX2`.
9. No one is able to respond to the challenge in period 2, so `TX1` is determined to be non-canonical.
10. After period 2, Bob’s `piggyback bond` is refunded, no one exits any UTXOs.
The challenger receives Bob’s `exit bond`.


### Mallory spends her input again later:

1. Mallory spends `UTXO1` in `TX1` to Bob, creating `UTXO2`.
2. `TX1` is included in block `N`.
3. Mallory spends `UTXO1` in `TX2`.
4. `TX2` is included in block `N+M`.
5. Mallory starts an exit referencing `TX1` and places `exit bond`.
6. In period 1, someone challenges the canonicity of `TX1` by revealing `TX2`.
7. In period 2, someone responds to the challenge by proving that `TX1` was included before `TX2`.
8. After period 2, the user who responded to the challenge receives Mallory’s `exit bond`, no one exits any UTXOs.


### Mallory attempts to exit a spent input:

1. Mallory spends `UTXO1` and `UTXO2` in `TX1`.
2. Mallory spends `UTXO1` in `TX2`.
3. `TX1` and `TX2` are in-flight.
4. Mallory starts an exit referencing `TX1` and places `exit bond`.
5. Mallory starts an exit referencing `TX2` and places `exit bond`.
6. In period 1 of the exit for `TX1`, someone challenges the canonicity of `TX1` by revealing `TX2`.
7. In period 1 of the exit for `TX2`, someone challenges the canonicity of `TX2` by revealing `TX1`.
8. After period 2 of the exit for `TX1`, the challenger receives `exit bond`, no one exits any UTXOs.
9. After period 2 of the exit for `TX2`, the challenger receives `exit bond`, no one exits any UTXOs.


### Operator tries to steal funds from an included transaction

1. Alice spends `UTXO1` in `TX1` to Bob, creating `UTXO2`.
2. `TX1` is included in (valid) block `N`.
3. Operator creates invalid deposit, creating `UTXO3`.
4. Operator spends `UTXO3` in `TX3`, creating `UTXO4`.
5. Operator starts an exit referencing `TX3` and places `exit bond`.
6. Operator piggybacks onto the exit and places `piggyback bond`.
7. Bob starts a *standard* exit for `UTXO2`.
8. Operator’s exit will have priority of position of `UTXO3`.
Bob’s exit will have priority of position of `UTXO2`.
9. Bob receives the value of `UTXO2` first, Operator receives the value of `UTXO4` second (ideally contract is empty by this point).
All bonds are refunded.

### Operator tries to steal funds from an in-flight transaction.

1. Alice spends `UTXO1` in `TX1` to Bob, creating `UTXO2`.
2. `TX1` is in-flight.
3. Operator creates invalid deposit, creating `UTXO3`.
4. Operator spends `UTXO3` in `TX3`, creating `UTXO4`.
5. Operator starts an exit referencing `TX3` and places `exit bond`.
6. Operator piggybacks onto the exit and places `piggyback bond`.
7. Bob starts an exit referencing `TX1` and places `exit bond`.
8. Bob piggybacks onto the exit and places `piggyback bond`.
9. Alice is honest, so she hasn’t spent `UTXO1` in any transaction other than `TX1`.
10. Operator’s exit will have priority of position of `UTXO3`.
Bob’s exit will have priority of position of `UTXO1`.
11. Bob receives the value of `UTXO2` first, Operator receives the value of `UTXO4` second (ideally contract is empty by this point).
All bonds are refunded.

### Operator tries to steal funds from a multi-input in-flight transaction.

1. Alice spends `UTXO1a`, Malory spends `UTXO1m` in `TX1` to Bob, creating `UTXO2`.
2. `TX1` is in-flight.
3. Operator creates invalid deposit, creating `UTXO3`.
4. Operator spends `UTXO3` in `TX3`, creating `UTXO4`.
5. Operator starts an exit referencing `TX3` and places `exit bond`.
6. Operator piggybacks onto the exit and places `piggyback bond`
7. Malory starts an exit referencing `TX1` and places `exit bond`.
8. Bob piggybacks onto the exit and places `piggyback bond`.
9. Alice piggybacks onto the exit and places `piggyback bond`.
9. Mallory double-spends `UTXO1m` in `TX2` and broadcasts.
9. Operator includes `TX2` and submits as a competitor to `TX1` rendering it non-canonical
10. Operator's exit of `TX3` will have priority of position of `UTXO3`.
Alice-Mallory exit will have priority of position of `UTXO1`.
11. Alice receives the value of `UTXO1a` first, Operator receives the value of `UTXO4` second (ideally contract is empty by this point).
Bob receives nothing.
Mallory's `exit bond` goes to the Operator.
Mallory's `TX2` is canonical and owners of outputs can attempt to exit them.

### Honest receiver should not start in-flight exits

An honest user obtaining knowledge about an in-flight transaction **crediting** them **should not** start an exit, otherwise risks having their exit bond slashed.

The out-of-band process in such event should always put the burden of starting in-flight exits **on the sender**.

The following scenario demonstrates an attack that is **possible if receivers are too eager to start in-flight exits**:
1. Mallory spends `UTXO1` in `TX1` to Bob, creating `UTXO2`.
2. `TX1` is in-flight.
3. Operator begins withholding blocks while `TX1` is still in-flight.
4. Bob **eaglerly** starts an exit referencing `TX1` and places `exit bond`.
5. Mallory spends `UTXO1` in `TX2`.
6. In period 1 of the exit for `TX1`, Mallory challenges the canonicity of `TX1` by revealing `TX2`.
7. No one is able to respond to the challenge in period 2, so `TX1` is determined to be non-canonical.
8. After period 2, Mallory receives Bob’s `exit bond`, no one exits any UTXOs.

Mallory has therefore caused Bob to lose `exit bond`, even though Bob was acting honestly.

### Attack Vectors and Mitigations

#### Honest Exit Bond Slashing

It’s possible for an honest user to start an exit and have their exit bond slashed.
This can occur if one of the inputs to a transaction is malicious and signs a second transaction spending the same input.

The following scenario demonstrates this attack:
1. Mallory spends `UTXO1m` and Alice spends `UTXO1a` in `TX1` to Bob, creating `UTXO2`.
2. `TX1` is in-flight.
3. Operator begins withholding blocks while `TX1` is still in-flight.
4. Alice starts an exit referencing `TX1` and places `exit bond`.
4. Alice piggybacks onto the exit and places `piggyback bond`.
5. Mallory spends `UTXO1m` in `TX2`.
6. In period 1 of the exit for `TX1`, Mallory challenges the canonicity of `TX1` by revealing `TX2`.
7. No one is able to respond to the challenge in period 2, so `TX1` is determined to be non-canonical.
8. After period 2, Mallory receives Alice's `exit bond`, Alice receives `UTXO1a` and `piggyback bond`.

Mallory has therefore caused Alice to lose `exit bond`, even though Alice was acting honestly.
We want to mitigate the impact of this attack as much as possible so that this does not prevent users from receiving funds.

**NOTE** in the scenarios where Mallory double-spends her input, she doesn't get to successfully piggyback that, unless the operator includes and makes canonical her double-spending transaction.
As a result she might lose more than she's getting from stolen `exit bonds`.

#### Honest transaction retries attack

Retrying a transaction that has failed for a trivial reason is not safe under MoreVP.

Scenario is:
1. Honest Alice creates/signs/submits a transaction `tx1`
2. This fails, either loudly (error response from child chain server) or quietly (no response) - `tx1` doesn't get included in a block
3. Alice is forced to in-flight exit, even if she just made a trivial mistake (e.g. incorrect fee)
4. If instead Alice retries with amended `tx2`, then she opens an attack on her funds:
    - if the child chain is nice, `tx2` will get included in a valid, non-withheld block, all is good
    - if the child chain decides to go rogue, Alice is left defenseless, because she double-spent her input, i.e. she can't in-flight exit neither `tx1` nor `tx2` anymore

See [Timeouts section](#Timeouts) for discussion on one possible mitigation.
However, due to uncertainty of timeouts in MoreVP, other mitigations for the retry problem might be necessary.

##### Mitigations for Honest Exit Bond Slashing

###### Bond Sharing

One way to partially mitigate this attack is for each user who piggybacks to cover some portion of `exit bond`.
This cuts the per-person value of `exit bond` proportionally to the number of users who have piggybacked.
Note that this is a stronger mitigation the more users are piggybacking on the exit and would not have any impact if only a single user starts the exit/piggybacks.


###### Small Exit Bond

The result of the above attack is that users may not exit from an in-flight transaction if the gas cost of exiting plus the value of `exit bond` is greater than the value of their input or output.
We can reduce the impact of this attack by minimizing the gas cost of exiting and the value of `exit bond`.
Gas cost should be highly optimized in any case, so the value of `exit bond` is of more importance.

`exit bond` is necessary to incentivize challenges.
However, we believe that challenges can be sufficiently incentivized if `exit bond` simply covers the gas cost of challenging.
Observations from the Bitcoin and Ethereum ecosystems suggest that sufficiently many nodes will verify transactions without a direct in-protocol incentive to do so.
Our system requires only a single node be properly incentivized to challenge, and it’s likely that many node operators will have strong external incentives.
Modeling the “correct” size of the exit bond is an ongoing area of research.


##### Timeouts

We can add timeouts to each transaction (“must be included in the chain by block X”) to
 - reduce number of transactions vulnerable to [**Honest Exit Bond Slashing**](#Honest-Exit-Bond-Slashing) point in time.
 - alleviate [**Honest transaction retries attack**](#Honest-transaction-retries-attack), allowing Alice to just wait the timeout and retry
This will probably also be necessary from a user experience point of view, as we don’t want users to accidentally sign a double-spend simply because the first transaction hasn’t been processed yet.

**TODO** At this point, it is uncertain how the timeouts scheme would modify MoreVP and whether it's feasible at all.

## Appendix

<!-- TODO: Clean up this entire proof section -->

### Formalization of Definitions

#### Transactions

$TX$ is the transaction space, where each transaction has $inputs$ and $outputs.
For simplicity, each input and output is an integer that represents the position of that input or output in the Plasma chain.

$$
TX: ((I_1, I_2, … ,I_n), (O_1, O_2, … ,O_m))
$$

For every transaction $t$ in $TX$ we define the “inputs” and “outputs” functions:

$$
I(t) = (I_1, I_2, …, I_n)
O(t) = (O_1, O_2, …, O_m)
$$


#### Chain

A Plasma chain is composed of transactions.
For each Plasma chain $T$, we define a mapping between each transaction position and the corresponding transaction at that position.

$$
T_n: [1, n] \rightarrow TX
$$

We also define a shortcut to point to a specific transaction in the chain.

$$
t_i = T_n(i)
$$


#### Competing Transaction, Competitors

Two transactions are competing if they have at least one input in common.

$$
competing(t, t’) = I(t) \cap I(t’) \neq \varnothing
$$

The set of competitors to a transaction is therefore every other transaction competing with the transaction in question.

$$
competitors(t) = \{ t_{i} : i \in (0, n], competing(t_{i}, t) \}
$$


#### Canonical Transaction

A transaction is called “canonical” if it’s oldest of all its competitors.
We define a function $first$ that determines which of a set $T$ of transactions is the oldest transaction.

$$
first(T) = t \in T : \forall t’ \in T, t \neq t’, min(O(t)) < min(O(t’))
$$

The set of canonical transactions is any transaction which is the first of all its competitors.

$$
canonical(t) = (first(competitors(t)) \stackrel{?}{=} t)
$$

For convenience, we define $reality$ as the set of all canonical transactions for a given chain.

$$
reality(T_{n}) = \{ canonical(t_{i}) : i \in [1, n] \}
$$


#### Unspent, Double Spent

We define two helper functions $unspent$ and $double\_spent$.
$unspent$ takes a set of transactions and returns the list of transaction outputs that haven't been spent.
$double\_spent$ takes a list of transactions and returns any outputs that have been used as inputs to more than one transaction.

First, we define a function $txo$ that takes a transaction and returns a list of its inputs and outputs.

$$
txo(t) =  O(t) \cup I(t)
$$

Next, we define a function $TXO$ that lists all inputs and outputs for an entire set of transactions:

$$
TXO(T_{n}) = \bigcup_{i = 1}^{n} txo(t_{i})
$$

Now we can define $unspent$ and $double\_spent$:

$$
unspent(T) = \{ o \in TXO(T) : \forall t \in T, o \not\in I(t) \}
$$

$$
double\_spent(T) = \{ o \in TXO(T) : \exists t,t' \in T, t \neq t', o \in I(t) \wedge o \in I(t') \}
$$

### Requirements

#### Safety

The safety rule, in English, says "if an output was exitable at some time and is not spent in a later transaction, then it must still be exitable".
If we didn't have this condition, then it might be possible for a user to receive money but not be able to spend or exit from it later.

Formally, if we say that $E(T_{n})$ represents the set of exitable outputs for some Plasma chain and $T_{n+1}$ is $T_{n}$ plus some new transaction $t_{n+1}$:

$$
\forall o \in E(T_{n}) : o \not\in I(t_{n+1}) \implies o \in E(T_{n+1})
$$


#### Liveness

The liveness rule states that "if an output was exitable at some time and *is* spent later, then immediately after that spend, either it's still exitable or all of the spend's outputs are exitable, but not both".

The second part ensures that something is spent, then all the resulting outputs should be exitable.
The first case is special - if the spend is invalid, then the outputs should not be exitable and the input should still be exitable.

$$
\forall o \in E(T_{n}), o \in I(t_{n+1}) \implies o \in E(T_{n+1}) \oplus O(t_{n+1}) \subseteq E(T_{n+1})
$$


### Basic Exit Protocol

#### Formalization

$$
E(T_{n}) = unspent(reality(T_{n})) \setminus double\_spent(T_{n})
$$


##### Priority

Exits are ordered by a given priority number.
An exit with a lower priority number will process before an exit with a higher priority number.
We define the priority of an exit from a transaction $t$, $p(t)$, as:

$$
p(t) = \max(I(t))
$$


#### Proof of Requirements

#### Safety

Our safety property says:

$$
\forall o \in E(T_{n}), o \not\in I(t_{n+1}) \implies o \in E(T_{n+1})
$$

So to prove this for our $E(T_{n})$, let's take some $o \in E(T_{n})$.
From our definition, $o$ must be in $unspent(reality(T_{n}))$, and must not be in $double\_spent(T_{n})$.

$o \not\in I(t_{n+1})$ means that $o$ will still be in $reality$, because only a transaction spending $o$ can impact its inclusion in $reality$.
Also, $o$ can't be spent (or double spent) if it wasn't used as an input.
So our function is safe!


#### Liveness

Our liveness property states:

$$
\forall o \in E(T_{n}), o \in I(t_{n+1}) \implies o \in E(T_{n+1}) \oplus O(t_{n+1}) \subseteq E(T_{n+1})
$$

However, *we do have a case for which liveness does not hold* - namely that if the second transaction is a non-canonical double spend, then both the input and all of the outputs will not be exitable.
This is a result of the $\setminus double\_spent(T_{n})$ clause.
We think this is fine, because it means that only double spent inputs are at risk of being "lost".

The updated property is therefore:
 $$
\forall o \in E(T_{n}), o \in I(t_{n+1}) \implies o \in E(T_{n+1}) \oplus O(t_{n+1}) \subseteq E(T_{n+1}) \oplus  o \in double\_spent(T_{n+1})
$$

This is more annoying to prove, because we need to show each implication holds separately, but not together.
Basically, given $\forall o \in E(T_{n}), o \in I(t_{n+1})$, we need:

$$
o \in E(T_{n+1}) \implies O(t_{n+1}) \cap E(T_{n+1}) = \varnothing \wedge  o \not\in double\_spent(T_{n+1})
$$

and

$$
O(t_{n+1}) \subseteq E(T_{n+1}) \implies o \not\in E(T_{n+1}) \wedge o \not\in double\_spent(T_{n+1})
$$

and

$$
o \in double\_spent(T_{n+1}) \implies O(t_{n+1}) \cap E(T_{n+1}) = \varnothing \wedge o \not\in E(T_{n+1})
$$

Let's show the first.
$o \in I(t_{n+1})$ means $o$ was spent in $t_{n+1}$.
However, $o \in E(T_{n+1})$ means that it's unspent in any canonical transaction.
Therefore, $t_{n+1}$ cannot be a canonical transaction.
$O(t_{n+1}) \cap E(T_{n+1})$ is empty if $t_{n+1}$ is not canonical, so we've shown the half.
Our specification states that $o \in double\_spent(T_{n+1}) \implies o \not\in E(T_{n+1})$, so we can show the second half by looking at the contrapositive of that statement $o \in E(T_{n+1}) \implies o \not\in double\_spent(T_{n+1})$.

Next, we'll show the second statement.
$O(t_{n+1}) \subseteq E(T_{n+1})$ implies that $t_{n+1}$ is canonical.
If $t_{n+1}$ is canonical, and $o$ is an input to $t_{n+1}$, then $o$ is no longer unspent, and therefore $o \not\in E(T_{n+1})$.
If $t$ is canonical then there cannot exist another earlier spend of the input, so  $o \not\in double\_spent(T_{n+1})$.

Now the third statement.
$o \in double\_spent(T_{n+1})$ means $t$ is necessarily not canonical, so we have $O(t_{n+1}) \cap E(T_{n+1}) = \varnothing$.
It also means that $o \not\in E(T_{n+1})$ because of our $\setminus double\_spent(T_{n})$ clause.

Finally, we'll show that at least one of these must be true.
Let's do a proof by contradiction.
Assume the following:

$$
 O(t_{n+1}) \cap E(T_{n+1}) = \varnothing \wedge o \not\in E(T_{n+1}) \wedge  o \not\in double\_spent(T_{n+1})
$$

We've already shown that:

$$
o \in E(T_{n+1}) \implies O(t_{n+1}) \cap E(T_{n+1}) = \varnothing \wedge  o \not\in double\_spent(T_{n+1})
$$

We can negate this statement to find:

$$
o \not\in E(T_{n+1}) \wedge (O(t_{n+1}) \subseteq E(T_{n+1}) \vee  o \in double\_spent(T_{n+1}))
$$

However, we assumed that:

$$

O(t_{n+1}) \cap E(T_{n+1}) = \varnothing \wedge  o \not\in double\_spent(T_{n+1})

$$

Therefore we've shown the statement by contradiction.


#### Exit Ordering

Let $t_{v}$ be some valid transaction and $t_{iv}$ be the first invalid, but still exitable and canonical, transaction in the chain.
$t_{iv}$ must either be a deposit transaction or spend some input that didn’t exist when $t_{v}$ was created, otherwise $t_{iv}$ would be valid.
Therefore:

$$
\max(I(t_{v})) < \max(I(t_{iv}))
$$

and therefore by our definition of $p(t)$:

$$
p(t_{v}) < p(t_{iv})
$$

So $p(t_{v})$ will exit before $p(t_{iv})$.
We now need to show that for any $t'$ that stems from $t_{iv}$, $p(t_{v}) < p(t')$ as well.
Because $t'$ stems from $t_{iv}$, we know that:

$$
(O(t_{iv}) \cap I(t') \neq \varnothing) \vee (\exists t : stems\_from(t_{iv}, t) \wedge stems\_from(t, t'))
$$

If the first is true, then we can show $p(t_{iv}) < p(t')$:

$$
p(t') = \max(I(t')) \geq \max(I(t') \cap O(t_{iv})) \geq \min(O(t_{iv})) > \max(I(t_{iv})) = p(t_{iv})
$$

Otherwise, there's a chain of transactions from $p_{iv}$ to $p'$ for which the first is true, and therefore the inequality holds by transitivity.
Therefore, all exiting outputs created by valid transactions will exit before any output created by an invalid transaction.
