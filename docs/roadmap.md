# OmiseGO Roadmap
The roadmap is a living document that records the steps in which we plan to deliver the functionality defined in the OmiseGO [whitepaper](https://cdn.omise.co/omg/whitepaper.pdf).

*Warning!* Milestones more than one release ahead of what we are working on is subject to change.

## Fuseki (Delivered!)
The Fuseki milestone was achieved in Q1 2018. Fuseki delivered the OmiseGO eWallet repositories, which included a server and mobile SDKs to onboard eWallet providers. Blockchain integration will be included in a later milestone.

The code for the eWallet SDK may be found in [GitHub](https://github.com/omisego/ewallet).

## Sente (Active)
The Sente milestone includes feedback from users of the closed beta and from Fuseki. Notable changes in the eWallet SDK from Fuseki to Sente includes:
* A re-designed administrative dashboard
* Transaction request flow (QR codes) to enable peer to peer payments between users

## Honte (Discontinued)
OmiseGO has stopped on the Honte milestone. The repository for Honte may be found [here](https://github.com/omisego/honted). The full design of the blockchain and decentralized exchange on Tendermint may be found [here](https://github.com/omisego/honted/blob/develop/docs/tendermint_blockchain_design.md) and [here](https://github.com/omisego/honted/blob/develop/docs/tendermint_blockchain_design.md) respectively.

## Tesuji (Active)
When the Tesuji milestone is reached, we will deliver OmiseGO's first implementation of Plasma. The design of Tesuji Plasma may be found [here](http://completeme).

* Proof of Authority run on OmiseGO servers.
* Exit to Ethereum for final safety.
* CLI to monitor the child chain.
* Atomic swap support (note that orders are not firm)
* Multiple currencies

We are actively seeking exchanges who wish to build an exchange front end and matching engine for Tesuji Plasma.

## Tengen
* Account simulation support
* Non-custodial on child chain order settlement
* Initial integration of eWallet SDK with ERC20 token support

## Tengen 2
* Decentralized order matching
* Initial integration of eWallet SDK with Plasma

## Step Up
* Removal of confirmation messages in Tesuji Plasma
* Conditional payments

## Tickets and Game items
* Non-fungible tokens

## Limited proof of stake
* Validators and the operator share the responsibility of securing the Plasma chain

## Aji
* Support fiat, debit/credit cards, top-up/cash-out, Omise Payment
* Plugin support in the eWallet SDK for cash in/cash out

## Shinte
* Provisions against validator/operator front-running
* Order blinding

## PoS
* Full proof of stake where the operator is removed

## On the Horizon and Approaching
* Direct exchange between wallet providers for tokens that are not issued on the blockchain
* Interchain communication
* Multiple root chains. ie different root chains for safety
* Child chain independence of root chain
* delegated exit initialization
* Economic incentives for exit and challenges (add bonds)
* Multiple child chains to a single root chain and nested chains
* Bitcoin clearinghouse
* Mobile light client, mobile trading app
