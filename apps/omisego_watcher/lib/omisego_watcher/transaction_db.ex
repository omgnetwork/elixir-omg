defmodule OmiseGOWatcher.TransactionDB do
  @moduledoc """
  Ecto Schema representing TransactionDB.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

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

  def find_by_txblknum(txblknum) do
    Repo.all(from(tr in __MODULE__, where: tr.txblknum == ^txblknum, select: tr))
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
          raw_tx: %Transaction{} = transaction,
          sig1: sig1,
          sig2: sig2
        },
        block_number,
        txindex
      ) do
    %__MODULE__{
      txid: id,
      txblknum: block_number,
      txindex: txindex,
    }
    |> Map.merge(Map.from_struct(transaction))
    |> Repo.insert()
  end

  def encode(%__MODULE__{} = tx) do
    [
      tx.txid,
      tx.blknum1,
      tx.txindex1,
      tx.oindex1,
      tx.blknum2,
      tx.txindex2,
      tx.oindex2,
      tx.newowner1,
      tx.amount1,
      tx.newowner2,
      tx.amount2,
      tx.fee,
      tx.txblknum,
      tx.txindex
    ]
    |> ExRLP.encode()
  end

  def changeset(transaction_db, attrs) do
    transaction_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
  end
end
