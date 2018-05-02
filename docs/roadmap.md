# OmiseGO Roadmap
The roadmap is a living document that records the steps in which we plan to deliver the functionality defined in the OmiseGO [whitepaper](https://cdn.omise.co/omg/whitepaper.pdf).

*Warning!* Milestones more than one release ahead of what we are working on is subject to change.

## Fuseki (Delivered!)
The Fuseki milestone was achieved in Q1 2018. Fuseki delivered the OmiseGO eWallet repositories, which included a server and mobile SDKs to onboard eWallet providers. Blockchain integration will be included in a later milestone.

The code for the eWallet SDK may be found in [GitHub](https://github.com/omisego/ewallet).

## Sente (In Progress)
The Sente milestone includes feedback from users of the closed beta and from Fuseki. Notable changes in the eWallet SDK from Fuseki to Sente includes:
* A re-designed administrative dashboard
* Transaction request flow (QR codes) to enable peer to peer payments between users

## Honte (Spooned)
OmiseGO has stopped on the Honte milestone. The repository for Honte may be found [here](https://github.com/omisego/honted). The full design of the blockchain and decentralized exchange on Tendermint may be found [here](https://github.com/omisego/honted/blob/develop/docs/tendermint_blockchain_design.md) and [here](https://github.com/omisego/honted/blob/develop/docs/batch_matching.md) respectively.

## Tesuji (In Progress)
When the Tesuji milestone is reached, we will deliver OmiseGO's first implementation of Plasma. Whilst not decentralized, Tesuji Plasma  does not compromise on security or performance. The design of Tesuji Plasma may be found [here](http://completeme).

* Proof of Authority run on OmiseGO servers.
* Exit to Ethereum for final safety.
* CLI to monitor the child chain.
* Atomic swap support (note that orders are not firm)
* Multiple currencies

We are actively seeking exchanges who wish to build an exchange front end and matching engine for Tesuji Plasma.

## Aji (On Deck)
* Support fiat, debit/credit cards, top-up/cash-out, Omise Payment
* Plugin support in the eWallet SDK for cash in/cash out

## TBN (To Be Named DEX Phase 1)
The implementation of the decentralized exchange is split across two phases. The first DEX phase maintains a centralized service to provide an order matching services. However, the order matching service does not have custody of funds at any time.

* Incentivize UTXO set reduction
* Non-custodial on child chain order settlement
* Initial integration of eWallet SDK with ERC20 token support

## TBN (To be Named DEX Phase 2)
DEX phase 2 fully decentralizes the exchange by moving the order book and order matching processes into the Plasma chain.
* Decentralized order matching
* Initial integration of eWallet SDK with Plasma

## TBN (To Be Named)
There are use cases where non-fungible tokens are useful, such as ticketing, unique in-game items.
* Removal of confirmation messages in Tesuji Plasma
* Conditional payments - Where payments are only made when a condition such as a date and time has passed, or when multiple signatures are present
* Non-fungible tokens

## TBN (To Be Named - Limited Proof of Stake)
This milestone will commence the phase-in of staking.

* Validators and the operator share the responsibility of securing the Plasma chain

## TBN (To Be Named - Proof of Stake)
* Full proof of stake where the operator is no longer required

## Shinte
The Shinte milestone includes enhancements to the decentralized exchange to mitigate unfair advantages that validators, the operator or other users may have over other users of the decentralized exchange.

Order blinding would allow users place an order whose details are not revealed until the order is live in the order book.
* Provisions against validator/operator front-running
* Order blinding

## Tengen (Goal)
The Tengen milestone is reached when the OMG Network:
* Has a decentralized exchange
* Uses Proof of Stake consensus
* Is highly scalable through multiple child chains
* Is able to interoperate with multiple different blockchains

Note that we plan to continue adding functionality and improving the OmiseGO network after we reach Tengen.

## On the Horizon and Approaching
Although these items may be at the bottom of this roadmap, it does not mean that they are low priority. Items in the `On the Horizon and Approaching` section may be prioritized and moved into a named milestone.
* Delegated exit initialization - Allows users who are unable to watch the Plasma chain all of the time to delegate responsibility to watch the Plasma and to exit on the user's behalf.
* Direct exchange between wallet providers for tokens that are not issued on the blockchain - This feature will enable functionality such as direct interchange of loyalty points between wallet providers.
* Multiple root chains. ie different root chains for safety
* Interchain communication - The ability for different child chains to communicate and transact.
* Child chain independence of root chain - increase safety of the Plasma chain which would in turn reduce dependency on the availability of the root chain
* Economic incentives for exit and challenges (add bonds)
* Multiple child chains to a single root chain and nested chains
* Bitcoin clearinghouse to enable trading on the decentralized exchange Bitcoin and Bitcoin-like cryptocurrencies
* Mobile light client, mobile trading app
