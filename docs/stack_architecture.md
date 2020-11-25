# OMG Network Client Architecture

This describes the client services stack that communicates with the child chain and root chain to secure the entire Plasma construction and ease application development. An application provider will run these client services on their own or use hosted versions.

## Foundations

### Root chain

#### Purpose

Trusted chain used by the Plasma construction to secure funds in the child chain. In our case, this is Ethereum.

### Child chain

#### Purpose

Blockchain of transactions for our application. Continually submits block hashes to the root chain, as required by the Plasma construction. Described in the [Tesuji design](tesuji_blockchain_design.md) and the [More Viable Plasma] documentation.

## Client Services

### Watcher

#### Purpose

The watcher first and foremost plays a critical security role in the system. The watcher monitors the child chain and root chain (Ethereum) for faulty activity.

#### Design principles

- Only include functionality that is critical to the operation of the Plasma security model
- Strict focus on security role reduces complexity and attack surface area
- Limited feature helps scalability
  - The more the watcher does, the slower it can verify
- 3 primary security functions:
  - Tracking of the root chain submissions, pulling block contents (from somewhere) and validating, in order to ensure safety of funds passively in possession on the child chain. Watcher notifies in case of the funds are jeopardized.
  - Proxy API to the child chain API (whatever it may be - PoA server or a P2P PoS network) and the root chain, that ensures that these two are never talked to if the chain is invalid or in unknown state. Only proxy calls that require the chain is operational.
  - Storage of data critical to access of the funds - UTXO positions, `txbytes` or any other kinds of proofs

#### Specifications

- [Current API](https://developer.omisego.co/elixir-omg/docs-ui/?url=0.2/security_critical_api_specs.yaml)

- Events
  - [Byzantine Events](https://github.com/omisego/elixir-omg/blob/master/docs/api_specs/status_events_specs.md#byzantine-events)

### Informational API Service

#### Purpose

Non-critical convenience API proxy and provide data about the chain.

#### Design principles

- Provide convenience APIs to proxy to the child chain/root chain/watcher to ease integration and reduce duplicate code in libraries
- Storage of informational data about the chain
- Support direct client requests (web browser, mobile, etc.)

#### Specifications

- [Current API](https://developer.omisego.co/elixir-omg/docs-ui/?url=0.2/info_api_specs.yaml)

### Integration libraries

#### Purpose

Native wrappers to the Watcher and Informational API Service for supported languages and frameworks.

#### Design principles

- Adopt all native conventions and standards
- Encourage open source community development

#### Requirements

- Support all events and API calls of the Watcher
- Support all events and API calls of the API Service

#### Current implementations

- [omg-js-lib](https://github.com/omgnetwork/omg-js)


### Application Layer

#### Purpose

Third party applications that use the OMG Network for value transfer and exchange.

#### Design principles

- Key management happens at this layer

#### Requirements

- Generate and secure keys
- Sign transactions
