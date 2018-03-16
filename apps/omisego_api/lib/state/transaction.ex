defmodule OmiseGO.API.State.Transaction do
  @moduledoc """
  Internal representation of a spend transaction on Plasma chain
  """

  alias OmiseGO.API.Crypto

  @zero_address <<0>> |> List.duplicate(20) |> Enum.join

  # TODO: probably useful to structure these fields somehow ore readable like
  # defstruct [:input1, :input2, :output1, :output2, :fee], with in/outputs as structs or tuples?
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
    @moduledoc false
    defstruct [:raw_tx, :sig1, :sig2, :hash]

    def hash(%__MODULE__{raw_tx: tx, sig1: sig1, sig2: sig2} = signed) do
      hash =
        (OmiseGO.API.State.Transaction.hash(tx) <> sig1 <> sig2)
        |> Crypto.hash()
      %{signed | hash: hash}
    end

  end

  defmodule Recovered do
    @moduledoc """
    Representation of a Signed transaction, with addresses recovered from signatures (from Transaction.Signed)
    Intent is to allow concurent processing of signatures outside of serial processing in state.ex
    """

    # FIXME: refactor to somewhere to avoid dupliaction
    @zero_address <<0>> |> List.duplicate(20) |> Enum.join

    # FIXME: rethink default values
    defstruct [:signed, spender1: @zero_address, spender2: @zero_address]

    def recover_from(%OmiseGO.API.State.Transaction.Signed{raw_tx: raw_tx, sig1: sig1, sig2: sig2} = signed) do
       hash_no_spenders = OmiseGO.API.State.Transaction.hash(raw_tx)
       spender1 = Crypto.recover_address(hash_no_spenders, sig1)
       spender2 = Crypto.recover_address(hash_no_spenders, sig2)
       %__MODULE__{signed: signed, spender1: spender1, spender2: spender2}
     end
  end

  # TODO: add convenience function for creating common transactions (1in-1out, 1in-2out-with-change, etc.)

  def zero_address, do: @zero_address

  def account_address?(address), do: address != @zero_address

  def hash(%__MODULE__{} = transaction) do
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
end
