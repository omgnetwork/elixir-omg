# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.WatcherInfo.DB.EthEvent do
  @moduledoc """
  Ecto schema for events logged by Ethereum
  """
  use Ecto.Schema

  import Ecto.Query

  alias Ecto.Multi

  alias OMG.Crypto
  alias OMG.Eth.Encoding
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB

  require Utxo

  @primary_key false
  schema "ethevents" do
    field(:root_chain_txhash, :binary, primary_key: true)
    field(:log_index, :integer, primary_key: true)

    field(:event_type, OMG.WatcherInfo.DB.Types.AtomType)

    field(:root_chain_txhash_event, :binary)

    many_to_many(
      :txoutputs,
      DB.TxOutput,
      join_through: DB.EthEventsTxOutputs,
      join_keys: [root_chain_txhash_event: :root_chain_txhash_event, child_chain_utxohash: :child_chain_utxohash]
    )

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Inserts deposits based on a list of event maps (if not already inserted before)
  """
  @spec insert_deposits!([OMG.State.Core.deposit()]) :: :ok | :error
  def insert_deposits!(deposits) do
    {_, status} =
      Enum.map_reduce(deposits, {:ok}, fn deposit, _ ->
        status = insert_deposit!(deposit)
        {status, status}
      end)

    status
  end

  @spec insert_deposit!(OMG.State.Core.deposit()) :: :ok | :error
  defp insert_deposit!(deposit) do
    result =
      Multi.new()
      |> Multi.insert(:ethevent, new_changeset(deposit, :deposit))
      |> Multi.insert(:txoutput, DB.TxOutput.new_changeset(deposit))
      |> Multi.insert(
        :ethevent_txoutput,
        fn %{ethevent: ethevent, txoutput: txoutput} ->
          DB.EthEventsTxOutputs.changeset(%{
            root_chain_txhash_event: ethevent.root_chain_txhash_event,
            child_chain_utxohash: txoutput.child_chain_utxohash
          })
        end
      )
      |> DB.Repo.transaction()

    case result do
      {:ok, _changes} -> :ok
      {:error, _failed_operation, _failed_value, _changes_so_far} -> :error
    end
  end

  @doc """
  Uses a list of encoded `Utxo.Position`s to insert the exits (if not already inserted before)
  """
  @spec insert_exits!([
          %{
            call_data: %{utxo_pos: pos_integer()},
            root_chain_txhash: charlist(),
            log_index: non_neg_integer()
          }
        ]) :: :ok | :error
  def insert_exits!(exits) do
    {_, status} =
      exits
      |> Enum.map(&utxo_exit_from_exit_event/1)
      |> Enum.map_reduce({:ok}, fn utxo_exit, _ ->
        status = insert_exit!(utxo_exit)
        {status, status}
      end)

    status
  end

  @spec insert_exit!(%{
          root_chain_txhash: binary(),
          log_index: non_neg_integer(),
          decoded_utxo_position: Utxo.Position.t()
        }) :: :ok | :error
  defp insert_exit!(%{
         root_chain_txhash: root_chain_txhash,
         log_index: log_index,
         decoded_utxo_position: {:utxo_position, blknum, txindex, oindex}
       }) do
    result =
      Multi.new()
      |> Multi.insert(
        :ethevent,
        new_changeset(%{root_chain_txhash: root_chain_txhash, log_index: log_index}, :standard_exit)
      )
      |> Multi.run(:txoutput, fn _, _ ->
        {:ok, txoutput} = DB.TxOutput.fetch_by(blknum: blknum, txindex: txindex, oindex: oindex)

        case txoutput.spending_txhash do
          nil -> {:ok, txoutput}
          spending_txhash -> {:error, "Cannot exit and already spent txoutput"}
        end
      end)
      |> Multi.insert(
        :ethevent_txoutput,
        fn %{ethevent: ethevent, txoutput: txoutput} ->
          DB.EthEventsTxOutputs.changeset(%{
            root_chain_txhash_event: ethevent.root_chain_txhash_event,
            child_chain_utxohash: txoutput.child_chain_utxohash
          })
        end
      )
      |> DB.Repo.transaction()

    case result do
      {:ok, _changes} -> :ok
      {:error, _failed_operation, _failed_value, _changes_so_far} -> :error
    end
  end

  def fetch_by(where_conditions) do
    DB.Repo.fetch(
      from(ethevents in __MODULE__,
        join: txoutputs in assoc(ethevents, :txoutputs),
        preload: [txoutputs: txoutputs],
        where: ^where_conditions,
        order_by: [asc: ethevents.updated_at]
      )
    )
  end

  @spec utxo_exit_from_exit_event(%{
          call_data: %{utxo_pos: pos_integer()},
          root_chain_txhash: charlist(),
          log_index: non_neg_integer()
        }) :: %{root_chain_txhash: binary(), log_index: non_neg_integer(), decoded_utxo_position: Utxo.Position.t()}
  defp utxo_exit_from_exit_event(%{
         call_data: %{utxo_pos: utxo_pos},
         root_chain_txhash: root_chain_txhash,
         log_index: log_index
       }) do
    %{
      root_chain_txhash: root_chain_txhash,
      log_index: log_index,
      decoded_utxo_position: Utxo.Position.decode!(utxo_pos)
    }
  end

  def new_changeset(%{root_chain_txhash: root_chain_txhash, log_index: log_index}, event_type) do
    changeset(%{
      root_chain_txhash: root_chain_txhash,
      log_index: log_index,
      event_type: event_type,
      root_chain_txhash_event: generate_root_chain_txhash_event(root_chain_txhash, log_index)
    })
  end

  @doc false
  def changeset(params \\ %{}) do
    fields = [:root_chain_txhash_event, :log_index, :root_chain_txhash, :event_type]

    %__MODULE__{}
    |> Ecto.Changeset.cast(params, fields)
    |> Ecto.Changeset.validate_required(fields)
    |> Ecto.Changeset.unique_constraint(:root_chain_txhash, name: :ethevents_pkey)
    |> Ecto.Changeset.unique_constraint(:root_chain_txhash_event)
  end

  def generate_root_chain_txhash_event(root_chain_txhash, log_index) do
    (Encoding.to_hex(root_chain_txhash) <> Integer.to_string(log_index)) |> Crypto.hash()
  end
end
