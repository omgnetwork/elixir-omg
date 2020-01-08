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
  import Ecto.Query

  use Ecto.Schema

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
      |> Multi.run(:deposit_not_exists?, event_not_exists?(deposit))
      |> Multi.insert(:insert_ethevent, new_changeset(deposit, :deposit))
      |> Multi.insert(:insert_txoutput, DB.TxOutput.new_changeset(deposit))
      |> Multi.insert(:ethevent_txoutput, fn %{insert_ethevent: ethevent, insert_txoutput: txoutput} ->
        DB.EthEventsTxOutputs.changeset(
          %DB.EthEventsTxOutputs{},
          %{
            root_chain_txhash_event: ethevent.root_chain_txhash_event,
            child_chain_utxohash: txoutput.child_chain_utxohash
          }
        )
      end)
      |> DB.Repo.transaction()

    case result do
      {:ok, _changes} -> :ok
      {:error, _failed_operation, _failed_value, _changes_so_far} -> :error
    end
  end

  def event_not_exists?(composite_key = %{root_chain_txhash: _, log_index: _}) do
    fn _, _ ->
      case get_by(composite_key) do
        nil -> {:ok, nil}
        existing_event -> {:error, existing_event}
      end
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
  defp insert_exit!(
         utxo_exit = %{
           root_chain_txhash: _,
           log_index: _,
           decoded_utxo_position: decoded_utxo_position
         }
       ) do
    result =
      Multi.new()
      |> Multi.run(:event_not_exists?, event_not_exists?(utxo_exit))
      |> Multi.run(:existing_utxo, DB.TxOutput.utxo_exists?(decoded_utxo_position))
      |> Multi.insert(:insert_ethevent, new_changeset(utxo_exit, :standard_exit))
      |> Multi.insert(:ethevent_txoutput, fn %{insert_ethevent: ethevent, existing_utxo: txoutput} ->
        DB.EthEventsTxOutputs.changeset(
          %DB.EthEventsTxOutputs{},
          %{
            root_chain_txhash_event: ethevent.root_chain_txhash_event,
            child_chain_utxohash: txoutput.child_chain_utxohash
          }
        )
      end)
      |> DB.Repo.transaction()

    case result do
      {:ok, _changes} -> :ok
      {:error, _failed_operation, _failed_value, _changes_so_far} -> :error
    end
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
    ethevent = %{
      root_chain_txhash: root_chain_txhash,
      log_index: log_index,
      event_type: event_type,
      root_chain_txhash_event: generate_root_chain_txhash_event(root_chain_txhash, log_index)
    }

    changeset(%__MODULE__{}, ethevent)
  end

  @doc false
  def changeset(struct, params \\ %{}) do
    fields = [:root_chain_txhash_event, :log_index, :root_chain_txhash, :event_type]

    struct
    |> Ecto.Changeset.cast(params, fields)
    |> Ecto.Changeset.validate_required(fields)
    |> Ecto.Changeset.unique_constraint(:root_chain_txhash, name: :ethevents_pkey)
    |> Ecto.Changeset.unique_constraint(:root_chain_txhash_event)
  end

  def generate_root_chain_txhash_event(root_chain_txhash, log_index) do
    (Encoding.to_hex(root_chain_txhash) <> Integer.to_string(log_index)) |> Crypto.hash()
  end

  def get_by(composite_keys) when is_list(composite_keys) do
    conditions =
      Enum.reduce(composite_keys, false, fn composite_key, conditions ->
        dynamic(
          [e],
          (e.root_chain_txhash == ^composite_key.root_chain_txhash and e.log_index == ^composite_key.log_index) or
            ^conditions
        )
      end)

    query =
      from(
        e in DB.EthEvent,
        select: e,
        where: ^conditions,
        order_by: [asc: e.updated_at],
        preload: [{:txoutputs, [:creating_transaction, :spending_transaction]}]
      )

    DB.Repo.all(query)
  end

  def get_by(%{:root_chain_txhash => root_chain_txhash, :log_index => log_index}) do
    DB.Repo.one(
      from(
        e in __MODULE__,
        where: e.root_chain_txhash == ^root_chain_txhash and e.log_index == ^log_index,
        order_by: [asc: e.updated_at],
        preload: [{:txoutputs, [:creating_transaction, :spending_transaction]}]
      )
    )
  end
end
