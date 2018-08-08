defmodule OmiseGOWatcher.UtxoDB do
  @moduledoc """
  Ecto schema for utxo
  """
  use Ecto.Schema

  alias OmiseGO.API.{Block, Crypto}
  alias OmiseGO.API.State.{Transaction, Transaction.Recovered, Transaction.Signed}
  alias OmiseGO.API.Utxo
  require Utxo
  alias OmiseGOWatcher.Repo
  alias OmiseGOWatcher.TransactionDB

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @field_names [:address, :currency, :amount, :blknum, :txindex, :oindex, :txbytes]
  def field_names, do: @field_names

  schema "utxos" do
    field(:address, :binary)
    field(:currency, :binary)
    field(:amount, :integer)
    field(:blknum, :integer)
    field(:txindex, :integer)
    field(:oindex, :integer)
    field(:txbytes, :binary)
  end

  defp consume_transaction(
         %Signed{raw_tx: %Transaction{} = transaction, signed_tx_bytes: signed_tx_bytes},
         txindex,
         block_number
       ) do
    make_utxo_db = fn transaction, number ->
      %__MODULE__{
        address: Map.get(transaction, :"newowner#{number}"),
        currency: Map.get(transaction, :cur12),
        amount: Map.get(transaction, :"amount#{number}"),
        blknum: block_number,
        txindex: txindex,
        oindex: Map.get(transaction, :"oindex#{number}"),
        txbytes: signed_tx_bytes
      }
    end

    {Repo.insert(make_utxo_db.(transaction, 1)), Repo.insert(make_utxo_db.(transaction, 2))}
  end

  defp remove_utxo(%Signed{raw_tx: %Transaction{} = transaction}) do
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

  def update_with(%{transactions: transactions, number: block_number}) do
    numbered_transactions = Stream.with_index(transactions)

    numbered_transactions
    |> Enum.map(fn {%Recovered{signed_tx: signed}, txindex} ->
      {remove_utxo(signed), consume_transaction(signed, txindex, block_number)}
    end)
  end

  @spec insert_deposits([
          %{
            owner: Crypto.address_t(),
            currency: Crypto.address_t(),
            amount: non_neg_integer(),
            block_height: pos_integer()
          }
        ]) :: :ok
  def insert_deposits(deposits) do
    deposits
    |> Enum.each(fn deposit ->
      Repo.insert(%__MODULE__{
        address: deposit.owner,
        currency: deposit.currency,
        amount: deposit.amount,
        blknum: deposit.block_height,
        txindex: 0,
        oindex: 0,
        txbytes: <<>>
      })
    end)
  end

  def compose_utxo_exit(Utxo.position(blknum, txindex, _) = decoded_utxo_pos) do
    txs = TransactionDB.find_by_txblknum(blknum)

    case Enum.any?(txs, fn tx -> tx.txindex == txindex end) do
      false -> {:error, :no_tx_for_given_blknum}
      true -> {:ok, compose_utxo_exit(txs, decoded_utxo_pos)}
    end
  end

  def compose_utxo_exit(txs, Utxo.position(_blknum, txindex, _) = decoded_utxo_pos) do
    sorted_txs = Enum.sort_by(txs, & &1.txindex)
    hashed_txs = Enum.map_every(sorted_txs, 1, fn tx -> tx.txid end)
    proof = Block.create_tx_proof(hashed_txs, txindex)
    tx = Enum.at(sorted_txs, txindex)

    utxo_pos = decoded_utxo_pos |> Utxo.Position.encode()

    %{
      utxo_pos: utxo_pos,
      txbytes: Transaction.encode(tx),
      proof: proof,
      sigs: tx.sig1 <> tx.sig2
    }
  end

  def get_all, do: Repo.all(__MODULE__)

  def get_utxo(address) do
    utxos = Repo.all(from(tr in __MODULE__, where: tr.address == ^address, select: tr))
    fields_names = List.delete(@field_names, :address)
    Enum.map(utxos, &Map.take(&1, fields_names))
  end

  @doc false
  def changeset(utxo_db, attrs) do
    utxo_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
  end
end
