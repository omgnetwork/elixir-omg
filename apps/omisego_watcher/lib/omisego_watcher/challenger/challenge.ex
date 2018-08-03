defmodule OmiseGOWatcher.Challenger.Challenge do
  @moduledoc """
  Represents a challenge
  """

  # NOTE: eutxoindex and cutxopos names were chosen for consistency with Solidity contract source code
  # eutoxoindex is index of exiting utxo in challenging transaction
  # cutxopos is position of challenging utxo
  defstruct cutxopos: 0, eutxoindex: 0, txbytes: nil, proof: nil, sigs: nil

  @type t() :: %__MODULE__{
          cutxopos: non_neg_integer(),
          eutxoindex: non_neg_integer(),
          txbytes: String.t(),
          proof: String.t(),
          sigs: String.t()
        }

  def create(cutxopos, eutxoindex, txbytes, proof, sigs) do
    txbytes = txbytes |> Base.encode16()
    proof = proof |> Base.encode16()
    sigs = sigs |> Base.encode16()
    %__MODULE__{cutxopos: cutxopos, eutxoindex: eutxoindex, txbytes: txbytes, proof: proof, sigs: sigs}
  end
end
