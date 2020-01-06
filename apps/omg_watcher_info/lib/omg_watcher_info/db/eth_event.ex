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
  @spec insert_deposits!([OMG.State.Core.deposit()]) :: :ok
  def insert_deposits!(deposits) do
    deposits |> Enum.each(&insert_deposit!/1)
  end

  @spec insert_deposit!(OMG.State.Core.deposit()) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  defp insert_deposit!(
         %{
           root_chain_txhash: root_chain_txhash,
           log_index: log_index,
           blknum: blknum,
           owner: owner,
           currency: currency,
           amount: amount
         } = deposit
       ) do
    case get_by_composite_pk(deposit) do
      nil ->
        event_type = :deposit
        position = Utxo.position(blknum, 0, 0)

        root_chain_txhash_event = generate_root_chain_txhash_event(root_chain_txhash, log_index)

        ethevent = %__MODULE__{
          root_chain_txhash_event: root_chain_txhash_event,
          log_index: log_index,
          root_chain_txhash: root_chain_txhash,
          event_type: event_type,
          txoutputs: []
        }

        child_chain_utxohash = DB.TxOutput.generate_child_chain_utxohash(position)

        txoutput = %DB.TxOutput{
          child_chain_utxohash: child_chain_utxohash,
          blknum: blknum,
          txindex: 0,
          oindex: 0,
          owner: owner,
          currency: currency,
          amount: amount,
          ethevents: []
        }

        ethevent_txoutput =
          DB.EthEventsTxOutputs.changeset(
            %DB.EthEventsTxOutputs{},
            %{
              root_chain_txhash_event: ethevent.root_chain_txhash_event,
              child_chain_utxohash: txoutput.child_chain_utxohash
            }
          )

        with {:ok, ethevent} <- DB.Repo.insert(ethevent),
             {:ok, txoutput} <- DB.Repo.insert(txoutput),
             {:ok, ethevent_txoutput} <- DB.Repo.insert(ethevent_txoutput) do
          {:ok, ethevent}
        else
          {:error, error} -> {:error, error}
        end

      existing_deposit ->
        {:ok, existing_deposit}
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
        ]) :: :ok
  def insert_exits!(exits) do
    exits
    |> Enum.map(&utxo_exit_from_exit_event/1)
    |> Enum.each(&insert_exit!/1)
  end

  @spec utxo_exit_from_exit_event(%{
          call_data: %{utxo_pos: pos_integer()},
          root_chain_txhash: charlist(),
          log_index: non_neg_integer()
        }) ::
          %{root_chain_txhash: binary(), log_index: non_neg_integer(), decoded_utxo_position: Utxo.Position.t()}
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

  @spec insert_exit!(%{
          root_chain_txhash: binary(),
          log_index: non_neg_integer(),
          decoded_utxo_position: Utxo.Position.t()
        }) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  defp insert_exit!(%{
         root_chain_txhash: root_chain_txhash,
         log_index: log_index,
         decoded_utxo_position: decoded_utxo_position
       }) do
    case get_by_composite_pk(%{root_chain_txhash: root_chain_txhash, log_index: log_index}) do
      nil ->
        case DB.TxOutput.get_by_position(decoded_utxo_position) do
          nil ->
            {:error, :utxo_does_not_exist}

          txoutput ->
            event_type = :standard_exit

            root_chain_txhash_event = generate_root_chain_txhash_event(root_chain_txhash, log_index)

            ethevent = %__MODULE__{
              root_chain_txhash_event: root_chain_txhash_event,
              log_index: log_index,
              root_chain_txhash: root_chain_txhash,
              event_type: event_type,
              txoutputs: []
            }

            ethevent_txoutput =
              DB.EthEventsTxOutputs.changeset(
                %DB.EthEventsTxOutputs{},
                %{
                  root_chain_txhash_event: ethevent.root_chain_txhash_event,
                  child_chain_utxohash: txoutput.child_chain_utxohash
                }
              )

            with {:ok, ethevent} <- DB.Repo.insert(ethevent),
                 {:ok, ethevent_txoutput} <- DB.Repo.insert(ethevent_txoutput) do
              {:ok, ethevent}
            else
              {:error, error} ->
                {:error, error}
            end
        end

      existing_exit ->
        {:ok, existing_exit}
    end
  end

  @doc false
  def changeset(struct, params \\ %{}) do
    fields = [:root_chain_txhash_event, :log_index, :root_chain_txhash, :event_type]

    Ecto.Changeset.cast(struct, params, fields)
  end

  def generate_root_chain_txhash_event(root_chain_txhash, log_index) do
    (Encoding.to_hex(root_chain_txhash) <> Integer.to_string(log_index)) |> Crypto.hash()
  end

  def get_by_composite_pks(composite_pks) do
    conditions =
      Enum.reduce(composite_pks, false, fn composite_pk, conditions ->
        dynamic(
          [e],
          (e.root_chain_txhash == ^composite_pk.root_chain_txhash and e.log_index == ^composite_pk.log_index) or
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

  def get_by_composite_pk(composite_pk) do
    conditions =
      dynamic([e], e.root_chain_txhash == ^composite_pk.root_chain_txhash and e.log_index == ^composite_pk.log_index)

    query =
      from(
        e in DB.EthEvent,
        select: e,
        where: ^conditions,
        order_by: [asc: e.updated_at],
        preload: [{:txoutputs, [:creating_transaction, :spending_transaction]}]
      )

    DB.Repo.one(query)
  end
end
