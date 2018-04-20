defmodule OmiseGOWatcher.TransactionDB do
  @moduledoc """
  Ecto Schema representing TransactionDB.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias OmiseGOWatcher.Repo
  alias OmiseGO.API.State.{Transaction, Transaction.Signed}
  alias OmiseGO.API.Block

  @field_names [
    :txid,
    :blknum1,
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
    :txblknum,
    :txindex
  ]
  def field_names, do: @field_names

  @primary_key {:txid, :binary, []}
  @derive {Phoenix.Param, key: :txid}
  @derive {Poison.Encoder, except: [:__meta__]}
  schema "transactions" do
    field(:blknum1, :integer)
    field(:txindex1, :integer)
    field(:oindex1, :integer)

    field(:blknum2, :integer)
    field(:txindex2, :integer)
    field(:oindex2, :integer)

    field(:newowner1, :string)
    field(:amount1, :integer)

    field(:newowner2, :string)
    field(:amount2, :integer)

    field(:fee, :integer)

    field(:txblknum, :integer)
    field(:txindex, :integer)
  end

  def get(id) do
    __MODULE__
    |> Repo.get(id)
  end

  def insert(%Block{transactions: transactions}, block_number) do
    transactions
    |> Stream.with_index
    |> Stream.map(fn {%Signed{} = signed, txindex} ->
      signed
      |> Signed.signed_hash()
      |> insert(signed, block_number, txindex)
    end)
    |> Enum.to_list()
  end

  def insert(
        id,
        %Signed{
          raw_tx: %Transaction{} = transaction
        },
        block_number,
        txindex
      ) do
    %__MODULE__{
      txid: id,
      txblknum: block_number,
      txindex: txindex
    }
    |> Map.merge(Map.from_struct(transaction))
    |> Repo.insert()
  end

  def changeset(transaction_db, attrs) do
    transaction_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
  end

  @doc """
  Gets transaction that spends given utxo
  """
  @spec get_transaction_spending_utxo(map()) :: {:ok, map()} | :utxo_not_spent
  def get_transaction_spending_utxo(%{blknum: blknum, txindex: txindex, oindex: oindex}) do
    query = from(
      t in __MODULE__,
      where:
        (t.blknum1 == ^blknum and t.txindex1 == ^txindex and t.oindex1 == ^oindex) or
        (t.blknum2 == ^blknum and t.txindex2 == ^txindex and t.oindex2 == ^oindex)
    )
    case Repo.all(query) do
      [] -> :utxo_not_spent
      [tx] -> {:ok, tx}
    end
  end

  @doc """
  Gets all transactions from the block
  """
  @spec get_transactions_by_block(non_neg_integer()) :: list(map())
  def get_transactions_by_block(txblknum) do
    query = from(
      t in __MODULE__,
      where: t.txbklnum == ^txblknum
    )
    Repo.all(query)
  end
end
