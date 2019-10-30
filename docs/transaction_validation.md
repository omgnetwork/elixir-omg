# Transaction validation

NOTE:
* input = utxo

This document presents current way of stateless and stateful validation of
`OMG.ChildChain.submit(encoded_signed_tx)` function.

#### Stateless validation

1. Decoding of encoded singed transaction using `OMG.State.Transaction.Signed.decode` method
    * Decoding using `ExRLP.decode` method and if fail then `{:error, :malformed_transaction_rlp}`
    * Decoding the raw structure of RLP items and if fail then `{:error, :malformed_transaction}`
    * Checking signatures lengths and if fail then `{:error, :bad_signature_length}`
    * Checking addresses/inputs/outputs/metadata and if fail then `{:error, :malformed_address}` / `{:error, :malformed_inputs}` / `{:error, :malformed_outputs}` / `{:error, :malformed_metadata}` respectively
2. Checking signed_tx using `OMG.State.Transaction.Recovered.recover_from`
    * if transaction have duplicated inputs then `{:error, :duplicate_inputs}`
    * if transaction's inputs intersperse with empty ones then `{:error, :inputs_contain_gaps}`
    * if transaction's outputs intersperse with empty ones then `{:error, :outputs_contain_gaps}`
    * if transaction have input and empty sig then  `{:error, :missing_signature}`
    * if transaction have empty input and non-empty sig then  `{:error, :superfluous_signature}`
    * Recovering address of spenders from signatures and if fail then `{:error, :signature_corrupt}`

#### Stateful validation

1. Validating block size
    * if the number of transactions in block exceeds limit then `{:error, :too_many_transactions_in_block}`
2. Checking correctness of input positions
    * if the input is from the future block then `{:error, :input_utxo_ahead_of_state}`
    * if the input does not exists then `{:error, :utxo_not_found}`
    * if the owner of input does not match with spender then `{:error, :unauthorized_spend}`
3. Checking if the amounts from the provided inputs adds up.
    * if not then `{:error, :amounts_do_not_add_up}`
4. (if in child chain server tx submission pipeline): see if the transaction pays the correct fee.
    * if not then `{:error, :fees_not_covered}`
