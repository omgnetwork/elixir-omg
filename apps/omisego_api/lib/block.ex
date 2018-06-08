defmodule OmiseGO.API.Block do
  @moduledoc """
  Representation of a OmiseGO block
  """

  alias OmiseGO.API.Block
  alias OmiseGO.API.Crypto

  @transaction_merkle_tree_height 16

  defstruct [:transactions, :hash, :number]

  @type t() :: %__MODULE__{
          transactions: list(OmiseGO.API.State.Transaction.Recovered.t()),
          hash: <<_::768>>,
          number: pos_integer
        }
  @doc """
  Returns block with merkle hash
  """
  @spec merkle_hash(%__MODULE__{}) :: %__MODULE__{}
  def merkle_hash(%__MODULE__{transactions: txs} = block) do
    hashed_txs = txs |> Enum.map(& &1.signed_tx_hash)
    {:ok, root} = MerkleTree.build(hashed_txs, &Crypto.hash/1, @transaction_merkle_tree_height)
    %Block{block | hash: root.value}
  end

  def create_utxo_proof(txs, txindex) do

    hashed_txs = txs |> Enum.map(&(&1.txid))

    {:ok, mt} = MerkleTree.new(hashed_txs, &Crypto.hash/1, @transaction_merkle_tree_height)

    tx_index = Enum.find_index(txs, fn(tx) -> tx.txindex == txindex end)

    proof = MerkleTree.Proof.prove(mt, tx_index)

    proof.hashes
      |> Enum.reverse
      |> Enum.reduce(fn(x, acc) -> acc <> x end)

  end
end
