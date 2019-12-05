# Transaction validation

NOTE:
* input = utxo

This document presents current way of stateless and stateful validation of
`OMG.ChildChain.submit(encoded_signed_tx)` function.

#### Stateless validation

1. Decoding of encoded singed transaction using `OMG.State.Transaction.Signed.decode` method
    * Decoding using `ExRLP.decode` method and if failed then `{:error, :malformed_transaction_rlp}`
    * Checking the transaction type and if not allowed then `{:error, :malformed_transaction}`
    * Decoding the raw structure of RLP items and if failed then `{:error, :malformed_transaction}`
    * Checking output type with respect to the parent transaction type and if failed then `{:error, :unrecognized_output_type}`
    * Checking addresses/inputs/outputs/metadata format and if failed then `{:error, :malformed_address}` / `{:error, :malformed_inputs}` / `{:error, :malformed_outputs}` / `{:error, :malformed_metadata}` respectively
    * Checking if outputs are non-empty and if failed then `{:error, :empty_outputs}`
    * Checking any integer values to be formatted validly and if failed then `{:error, :leading_zeros_in_encoded_uint}` or `{:error, :encoded_uint_too_big}` accordingly
    * Checking all amount-representing values to non-zero and if failed then `{:error, :amount_cant_be_zero}`
2. Checking and recovering (preprocessing) a decoded `Transaction.Signed` using `OMG.State.Transaction.Recovered`
    * Checking if transaction doesn't have duplicated inputs and if failed then `{:error, :duplicate_inputs}`
    * Checking if signatures are in correct format and lengths and if failed then `{:error, :malformed_witnesses}`
    * Checking if transaction has no missing signature for an input supplied and if failed then `{:error, :missing_signature}`
    * Checking if transaction has no missing input for a signature supplied and if failed then `{:error, :superfluous_signature}`
    * Recovering addresses of spenders from signatures and if failed then `{:error, :signature_corrupt}`

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
