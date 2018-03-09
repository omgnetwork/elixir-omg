defmodule OmiseGO.API.State.Transaction do

  @zero_address List.duplicate(<<0>>, 20) |> Enum.join

  defstruct [:blknum1,
             :txindex1,
             :oindex1,
             :blknum2,
             :txindex2,
             :oindex2,
             :newowner1,
             :amount1,
             :newowner2,
             :amount2,
             :fee,
             ]

  defmodule Signed do
    defstruct [:raw_tx, :sig1, :sig2]
  end

  defmodule Recovered do

     # FIXME: refactor to somewhere to avoid dupliaction
     @zero_address List.duplicate(<<0>>, 20) |> Enum.join

     # FIXME: rethink default values
     defstruct [:raw_tx, spender1: @zero_address, spender2: @zero_address]

     def recover_from(%OmiseGO.API.State.Transaction.Signed{raw_tx: raw_tx, sig1: sig1, sig2: sig2}) do
       hash_no_spenders = OmiseGO.API.State.Transaction.raw_tx_hash(raw_tx)
       spender1 = recover_public_address(hash_no_spenders, sig1)
       spender2 = recover_public_address(hash_no_spenders, sig2)
       %__MODULE__{raw_tx: raw_tx, spender1: spender1, spender2: spender2}
     end

     defp recover_public_address(transaction_hash_no_spenders, sig) do
       transaction_hash_no_spenders
       |> OmiseGO.API.Crypto.recover_public(sig)
     end
  end

  def new_deposit(owner, amount) do
    %__MODULE__{zero_transaction | newowner1: owner, amount1: amount, newowner2: @zero_address}
  end

  def account_address?(address), do: address != @zero_address

  def raw_tx_hash(%__MODULE__{} = transaction) do
    #FIXME: is that a proper structure for RLP?
    [transaction.blknum1,
     transaction.txindex1,
     transaction.oindex1,
     transaction.blknum2,
     transaction.txindex2,
     transaction.oindex2,
     transaction.newowner1,
     transaction.amount1,
     transaction.newowner2,
     transaction.amount2,
     transaction.fee]
    |> ExRLP.encode
    |> OmiseGO.API.Crypto.hash()
  end

  defp zero_transaction do
    # FIXME: rethink what would be the best approach here
    %__MODULE__{
      blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
      amount1: 0, amount2: 0, fee: 0,
    }
  end

end
