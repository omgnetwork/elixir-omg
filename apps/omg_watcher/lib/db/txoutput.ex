# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.DB.TxOutput do
  @moduledoc """
  Ecto schema for transaction's output or input
  """
  use Ecto.Schema

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.DB
  alias OMG.Watcher.DB.Repo

  require Utxo

  import Ecto.Query, only: [from: 2, where: 2]

  @type balance() :: %{
          currency: binary(),
          amount: non_neg_integer()
        }

  @type exit_t() :: %{
          utxo_pos: pos_integer(),
          txbytes: binary(),
          proof: binary(),
          sigs: binary()
        }

  @primary_key false
  schema "txoutputs" do
    field(:blknum, :integer, primary_key: true)
    field(:txindex, :integer, primary_key: true)
    field(:oindex, :integer, primary_key: true)
    field(:owner, :binary)
    field(:amount, OMG.Watcher.DB.Types.IntegerType)
    field(:currency, :binary)
    field(:proof, :binary)
    field(:spending_tx_oindex, :integer)

    belongs_to(:creating_transaction, DB.Transaction, foreign_key: :creating_txhash, references: :txhash, type: :binary)
    belongs_to(:deposit, DB.EthEvent, foreign_key: :creating_deposit, references: :hash, type: :binary)

    belongs_to(:spending_transaction, DB.Transaction, foreign_key: :spending_txhash, references: :txhash, type: :binary)
    belongs_to(:exit, DB.EthEvent, foreign_key: :spending_exit, references: :hash, type: :binary)
  end

  @spec compose_utxo_exit(Utxo.Position.t()) :: {:ok, exit_t()} | {:error, :utxo_not_found}
  def compose_utxo_exit(Utxo.position(blknum, txindex, _) = decoded_utxo_pos) do
    if is_deposit(decoded_utxo_pos) do
      compose_deposit_exit(decoded_utxo_pos)
    else
      txs = DB.Transaction.get_by_blknum(blknum)

      if txs |> Enum.any?(&match?(%{txindex: ^txindex}, &1)),
        do: {:ok, compose_output_exit(txs, decoded_utxo_pos)},
        else: {:error, :utxo_not_found}
    end
  end

  @spec is_deposit(Utxo.Position.t()) :: boolean()
  defp is_deposit(Utxo.position(blknum, _, _)) do
    {:ok, interval} = OMG.Eth.RootChain.get_child_block_interval()
    rem(blknum, interval) != 0
  end

  defp compose_deposit_exit(decoded_utxo_pos) do
    with %{amount: amount, currency: currency, owner: owner} <- get_by_position(decoded_utxo_pos) do
      tx = Transaction.new([], [{owner, currency, amount}])

      block = %Block{
        transactions: [%Transaction.Signed{raw_tx: tx, sigs: []} |> Transaction.Signed.encode()]
      }

      {:ok,
       %{
         utxo_pos: decoded_utxo_pos |> Utxo.Position.encode(),
         txbytes: tx |> Transaction.encode(),
         proof: Block.inclusion_proof(block, 0)
       }}
    else
      _ -> {:error, :no_deposit_for_given_blknum}
    end
  end

  defp compose_output_exit(txs, Utxo.position(_blknum, txindex, _) = decoded_utxo_pos) do
    # TODO: Make use of Block API's block.get when available
    sorted_tx_bytes =
      txs
      |> Enum.sort_by(& &1.txindex)
      |> Enum.map(& &1.txbytes)

    signed_tx = Enum.at(sorted_tx_bytes, txindex)

    {:ok,
     %Transaction.Signed{
       raw_tx: raw_tx,
       sigs: sigs
     }} = Transaction.Signed.decode(signed_tx)

    proof =
      %Block{transactions: sorted_tx_bytes}
      |> Block.inclusion_proof(txindex)

    utxo_pos = decoded_utxo_pos |> Utxo.Position.encode()
    sigs = Enum.join(sigs)

    %{
      utxo_pos: utxo_pos,
      txbytes: Transaction.encode(raw_tx),
      proof: proof,
      sigs: sigs
    }
  end

  def get_all, do: Repo.all(__MODULE__)

  @spec get_by_position(Utxo.Position.t()) :: map() | nil
  def get_by_position(Utxo.position(blknum, txindex, oindex)) do
    Repo.get_by(__MODULE__, blknum: blknum, txindex: txindex, oindex: oindex)
  end

  def get_utxos(owner) do
    query =
      from(
        txo in __MODULE__,
        where: txo.owner == ^owner and is_nil(txo.spending_txhash) and is_nil(txo.spending_exit),
        order_by: [asc: :blknum, asc: :txindex, asc: :oindex],
        preload: [:creating_transaction, :deposit]
      )

    Repo.all(query)
  end

  @spec get_balance(OMG.Crypto.address_t()) :: list(balance())
  def get_balance(owner) do
    query =
      from(
        t in __MODULE__,
        where: t.owner == ^owner and is_nil(t.spending_txhash) and is_nil(t.spending_exit),
        group_by: t.currency,
        select: {t.currency, sum(t.amount)}
      )

    Repo.all(query)
    |> Enum.map(fn {currency, amount} ->
      # defends against sqlite that returns integer here
      amount = amount |> Decimal.new() |> Decimal.to_integer()
      %{currency: currency, amount: amount}
    end)
  end

  @spec spend_utxos([map()]) :: :ok
  def spend_utxos(db_inputs) do
    db_inputs
    |> Enum.each(fn {Utxo.position(blknum, txindex, oindex), spending_oindex, spending_txhash} ->
      _ =
        DB.TxOutput
        |> where(blknum: ^blknum, txindex: ^txindex, oindex: ^oindex)
        |> Repo.update_all(set: [spending_tx_oindex: spending_oindex, spending_txhash: spending_txhash])
    end)
  end

  @spec create_outputs(pos_integer(), integer(), binary(), %Transaction{}) :: [map()]
  def create_outputs(
        blknum,
        txindex,
        txhash,
        tx
      ) do
    # zero-value outputs are not inserted, tx can have no outputs at all
    outputs =
      tx
      |> Transaction.get_outputs()
      |> Enum.with_index()
      |> Enum.flat_map(fn {%{currency: currency, owner: owner, amount: amount}, oindex} ->
        create_output(blknum, txindex, oindex, txhash, owner, currency, amount)
      end)

    outputs
  end

  defp create_output(_blknum, _txindex, _txhash, _oindex, _owner, _currency, 0), do: []

  defp create_output(blknum, txindex, oindex, txhash, owner, currency, amount) when amount > 0,
    do: [
      %{
        blknum: blknum,
        txindex: txindex,
        oindex: oindex,
        owner: owner,
        amount: amount,
        currency: currency,
        creating_txhash: txhash
      }
    ]

  @spec create_inputs(%Transaction{}, binary()) :: [tuple()]
  def create_inputs(%Transaction{inputs: inputs}, spending_txhash) do
    inputs
    |> Enum.with_index()
    |> Enum.map(fn {%{blknum: blknum, txindex: txindex, oindex: oindex}, index} ->
      {Utxo.position(blknum, txindex, oindex), index, spending_txhash}
    end)
  end

  @spec get_sorted_grouped_utxos(OMG.Crypto.address_t()) :: %{OMG.Crypto.address_t() => list(%__MODULE__{})}
  def get_sorted_grouped_utxos(owner) do
    # TODO: use clever DB query to get following out of DB
    get_utxos(owner)
    |> Enum.group_by(& &1.currency)
    |> Enum.map(fn {k, v} -> {k, Enum.sort_by(v, & &1.amount, &>=/2)} end)
    |> Map.new()
  end
end
