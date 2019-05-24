# Integration libraries

## Transaction RLP-encoding

Library function which encapsulates transaction's RLP-serialization to the form understand by the contract's code.

### Input
Standard transaction structure e.g. `OMG.State.Transaction` or JSON structure like current `transaction.create` convenience endpoint.

### Output
RLP-encoded binary representation of the transaction which can be signed and submit via [Submit transaction](#)
