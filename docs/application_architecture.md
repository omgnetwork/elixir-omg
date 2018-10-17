## OmiseGO Application Architecture

### Watcher Service

#### Purpose

The watcher first and foremost plays a critical security role in the system.

#### Design principle

- Only include functionality that is critical to the operation of the Plasma security model
- Strict focus on security role reduces complexity and attack surface area
- Limited feature helps scalability
  - The more the watcher does, the slower it can verify
- 3 primary security functions:
  - Tracking of the root chain submissions, pulling block contents (from somewhere) and validating, in order to ensure safety of funds passively in possession on the child chain. Watcher notifies in case of the funds are jeopardized.
  - Proxy API to the child chain API (whatever it may be - PoA server or a P2P PoS network) and the root chain, that ensures that these two are never talked to if the chain is invalid or in unknown state. Only proxy calls that require the chain is operational.
  - Storage of data critical to access of the funds - UTXO positions, `txbytes` or any other kinds of proofs

#### Requirements

- Events
  - Should exit due to fault
    - Double spend
    - Invalid exit started
    - Transaction spent
    - Out of nowhere transaction created
    - Block withholding?
    - ...
  - Standard exit started
  - Standard exit challenged
  - In-flight exit started
  - In-flight exit challenged
  - Successful exit
  - Transaction in block
  - New deposit
  - New transaction
  - New block
- API
  - Submit transaction
  - Start exit
  - Challenge exit
  - ...

### Informational API Service

#### Purpose

Non-critical convenience API proxy and provide data about the chain.

#### Design principle

- Provide convenience APIs to proxy to the child chain/root chain/watcher to ease integration and reduce duplicate code in libraries
- Storage of informational data about the chain
- Support direct client requests (web browser, mobile, etc.)

#### Requirements

- Events
  - ...
- API
  - Getting all blocks
  - Getting a block and its transactions
  - Getting all transactions (paginated, per address, per list of addresses)
  - Get specific transaction (by id)
  - Getting UTXOs (paginated, per address, per list of addresses?)
  - Get balance by address
  - Build transaction
  - Submit signed transaction
  - Get specific transaction (by correlation field)
- UTXO management?


### Integration libraries

#### Purpose

Native wrappers to the Watcher and Informational API Service for supported languages and frameworks.

#### Design principle

- Adopt all native conventions and standards
- Encourage open source community development

#### Requirements

- Support all events and API calls of the Watcher
- Support all events and API calls of the API Service


### Application Layer

#### Purpose

Third party applications that use the OmiseGO Network for value transfer and exchange.

#### Design principles

- Key management happens at this layer

#### Requirements

- Generate and secure keys
- Sign transactions
