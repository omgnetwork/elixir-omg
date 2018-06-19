defmodule OmiseGOWatcher.UtxoDB do
  @moduledoc """
  Ecto schema for utxo
  """
  use Ecto.Schema

  alias OmiseGO.API.{Block, Crypto}
  alias OmiseGO.API.State.{Transaction, Transaction.Recovered}
  alias OmiseGOWatcher.Repo

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @field_names [:address, :amount, :blknum, :txindex, :oindex, :txbytes]
  def field_names, do: @field_names

  schema "utxos" do
    field(:address, :string)
    field(:amount, :integer)
    field(:blknum, :integer)
    field(:txindex, :integer)
    field(:oindex, :integer)
    field(:txbytes, :binary)
  end

  defp consume_transaction(
         %Recovered{raw_tx: %Transaction{} = transaction, signed_tx_bytes: signed_tx_bytes},
         txindex,
         block_number
       ) do
    make_utxo_db = fn transaction, number ->
      %__MODULE__{
        address: Map.get(transaction, :"newowner#{number}"),
        amount: Map.get(transaction, :"amount#{number}"),
        blknum: block_number,
        txindex: txindex,
        oindex: Map.get(transaction, :"oindex#{number}"),
        txbytes: signed_tx_bytes
      }
    end

    {Repo.insert(make_utxo_db.(transaction, 1)), Repo.insert(make_utxo_db.(transaction, 2))}
  end

  defp remove_utxo(%Recovered{
         raw_tx: %Transaction{} = transaction
       }) do
    remove_from = fn transaction, number ->
      blknum = Map.get(transaction, :"blknum#{number}")
      txindex = Map.get(transaction, :"txindex#{number}")
      oindex = Map.get(transaction, :"oindex#{number}")

      elements_to_remove =
        from(
          utxoDb in __MODULE__,
          where: utxoDb.blknum == ^blknum and utxoDb.txindex == ^txindex and utxoDb.oindex == ^oindex
        )

      elements_to_remove |> Repo.delete_all()
    end

    {remove_from.(transaction, 1), remove_from.(transaction, 2)}
  end

  def consume_block(%Block{transactions: transactions, number: block_number}) do
    numbered_transactions = Stream.with_index(transactions)

    numbered_transactions
    |> Enum.map(fn {%Recovered{} = recovered, txindex} ->
      {remove_utxo(recovered), consume_transaction(recovered, txindex, block_number)}
    end)
  end

  @spec insert_deposits([
          %{owner: Crypto.address_t(), amount: non_neg_integer(), block_height: pos_integer()}
        ]) :: :ok
  def insert_deposits(deposits) do
    deposits
    |> Enum.each(fn deposit ->
      Repo.insert(%__MODULE__{
        address: deposit.owner,
        amount: deposit.amount,
        blknum: deposit.block_height,
        txindex: 0,
        oindex: 0,
        txbytes: <<>>
      })
    end)
  end

  def get_all, do: Repo.all(__MODULE__)

  @doc false
  def changeset(utxo_db, attrs) do
    utxo_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
  end
end
