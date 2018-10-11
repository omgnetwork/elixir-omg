## Tesuji Plasma Transaction Format

### Motivation

To be able to make an alternative implementation of a library and allowing for generation of a plasma transaction without referring to reference `elixir-omg` source code.

As long as RLP encoding is available, Plasma transaction could be implemented in any programming language

### High Level Process

On a high level, completing plasma transaction requires the following process:

1. Create the transaction Object/Struct
2. Sign the transaction
3. Encode the transaction in RLP
4. Encode the transaction in Base16
5. Submit the transaction to child chain server via JSON RPC

### Caveats

Current implementation of Tesuji Plasma as of this writing is capable of only taking 2 inputs, 2 outputs and 2 signatures. This is subject to changes in the future

Each programming language comes with its own unique type systems. Ie. in elixir implementation supports arrays of bytes. However JavaScript has uint8Arrays but signing and encoding requires transforming the data into type Buffer. Each implementation is responsible for their type conversions


## 1. Create the Transaction Object/Struct

Firstly, a transaction object/struct needs to be created with the following array structure:

```
rawTransactionInput = [blknum1, txindex1, oindex1, blknum2, txindex2, oindex2, cur12, newowner1, amount1, newowner2, amount2]
```

**`blknum`**: the Block number of the transaction within the child chain  

**`txindex`**: the transaction index within the block

**`oindex`**: the transaction output index

**`cur12`**: the currency of the transaction - Ethereum address (20 bytes) (all zeroes for ETH)

**`newowner`**: the address of the new owner of the utxo - Ethereum address (20 bytes)

**`amount`**: the amount belongs to the new owner of the utxo

## 2. Sign the transaction

### 2.1 Signature

A Signature  `signature1` of the rawTransactionInput will then be created by:

- Encoding the transaction with RLP
- Signing the transaction with a private key via ECDSA Signing Algorithm

```
signature1 = ecsign(rlpEncode(rawTransactionInput), privatekey1)
```

The implementation of this step is crucial, given that it dictates how key management process is done.
For the sake of simplicity - we assume that transaction is signed by raw `privatekey1`.

### 2.2 Generate transaction array - `txArray`

We will need to create another array containing the signature and all of the elements from `rawTransactionInput`.
Refer to the following:

```
Let txArray = [blknum1, txindex1, oindex1, blknum2, txindex2, oindex2, cur12, newowner1, amount1, newowner2, amount2, signature1, signature2]
```

Note: `signature2` is derived by the same process as `signature1`, given that we only need 1 signature to make this transaction, the input for `signature2` will be 65-byte array of zeroes.

### 2.3. RLP Encode txArray

Encode `txArray` with `RLP` encoding algorithm.
The end output of the signed transaction is:

```
signedTxBytes = rlpEncode(txArray)
```

## 4. Encode the transaction in Base 16

Encode the RLP encoded input with Base16 into a string.
IMPORTANT: ensure that the value to be Base16 encoded is lowercase, as current  implementation of Tesuji Plasma will reject capital case

```
base16Encoded = base16Encode(signedTxBytes)
```

## 5. Submit the transaction to child chain server via JSON RPC

Submitting the Base16 encoded transaction as String to child chain server via JSON RPC

Illustrated using curl command:
```
curl “http://localhost:9656” -d ‘{“params”:{“transaction”: <base16Encoded> }, “method”: “submit”, “jsonrpc”: “2.0",“id”:0}’
```
