defmodule OmiseGO.API.Block do
  @moduledoc """
  Representation of a OmiseGO block
  """

  alias OmiseGO.API.Block
  alias OmiseGO.API.Crypto

  @empty_transaction_hash <<0>> |> List.duplicate(32) |> Enum.join
  @transactions_in_block 65536

  defstruct [:transactions, :hash]

  @doc """
  Returns block with merkle hash
  """
  @spec merkle_hash(%__MODULE__{}) :: %__MODULE__{}
  def merkle_hash(%__MODULE__{transactions: txs}) do
    hashed_txs =
      txs
      |> Enum.map(&(&1.hash))
    leaves = hashed_txs ++
             List.duplicate(@empty_transaction_hash, @transactions_in_block - length(hashed_txs))
    root = MerkleTree.build(leaves, &Crypto.hash/1)
    %Block{transactions: txs, hash: root.value}
  end
end
