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
  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset

  use Ecto.Schema

  alias OMG.Crypto
  alias OMG.Eth.Encoding
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WireFormatTypes

  require Utxo

  @typep available_event_type_t() :: :standard_exit | :in_flight_exit

  @primary_key false
  schema "ethevents" do
    field(:root_chain_txhash, :binary, primary_key: true)
    field(:log_index, :integer, primary_key: true)

    field(:event_type, OMG.WatcherInfo.DB.Types.AtomType)

    field(:root_chain_txhash_event, :binary)

    many_to_many(
      :txoutputs,
      DB.TxOutput,
      join_through: DB.EthEventTxOutput,
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
  defp insert_deposit!(%{
         root_chain_txhash: root_chain_txhash,
         log_index: log_index,
         blknum: blknum,
         owner: owner,
         currency: currency,
         amount: amount
       }) do
    event_type = :deposit
    position = Utxo.position(blknum, 0, 0)
    root_chain_txhash_event = generate_root_chain_txhash_event(root_chain_txhash, log_index)

    case get(root_chain_txhash_event) do
      nil ->
        %__MODULE__{
          root_chain_txhash_event: root_chain_txhash_event,
          log_index: log_index,
          root_chain_txhash: root_chain_txhash,
          event_type: event_type,

          # a deposit from the root chain will only ever have 1 childchain txoutput object
          txoutputs: [
            %DB.TxOutput{
              child_chain_utxohash: generate_child_chain_utxohash(position),
              blknum: blknum,
              txindex: 0,
              oindex: 0,
              otype: WireFormatTypes.output_type_for(:output_payment_v1),
              owner: owner,
              currency: currency,
              amount: amount
            }
          ]
        }
        |> DB.Repo.insert()

        # an ethevents row just got inserted, now return the ethevent with all populated fields including
        # those populated by the DB (eg: inserted_at, updated_at, ...)
        {:ok, get(root_chain_txhash_event)}

      existing_deposit ->
        {:ok, existing_deposit}
    end
  end

  @doc """
  Uses a list of encoded `Utxo.Position`s to insert the exits (if not already inserted before)
  """
  @spec insert_exits!([non_neg_integer()], available_event_type_t()) :: :ok
  def insert_exits!(exits, event_type \\ :standard_exit) do
    exits
    |> Stream.map(&utxo_exit_from_exit_event/1)
    |> Enum.each(&insert_exit!(&1, event_type))
  end

  def txoutput_changeset(txoutput, params, ethevent) do
    fields = [:blknum, :txindex, :oindex, :owner, :amount, :currency, :child_chain_utxohash]

    txoutput
    |> cast(params, fields)
    |> put_assoc(:ethevents, txoutput.ethevents ++ [ethevent])
    |> validate_required(fields)
  end

  @doc """
  Generate a unique child_chain_utxohash from the Utxo.position
  """
  @spec generate_child_chain_utxohash(Utxo.Position.t()) :: OMG.Crypto.hash_t()
  def generate_child_chain_utxohash(position) do
    "<#{position |> Utxo.Position.encode()}>" |> Crypto.hash()
  end

  def generate_root_chain_txhash_event(root_chain_txhash, log_index) do
    (Encoding.to_hex(root_chain_txhash) <> Integer.to_string(log_index)) |> Crypto.hash()
  end

  # preload txoutputs in a single query as there will not be a large number of them
  def get(root_chain_txhash_event) do
    DB.Repo.one(
      from(ethevent in __MODULE__,
        where: ethevent.root_chain_txhash_event == ^root_chain_txhash_event,
        left_join: txoutputs in assoc(ethevent, :txoutputs),
        preload: [txoutputs: txoutputs]
      )
    )
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

  @spec insert_exit!(
          %{
            root_chain_txhash: binary(),
            log_index: non_neg_integer(),
            decoded_utxo_position: Utxo.Position.t()
          },
          available_event_type_t()
        ) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()} | :noop
  defp insert_exit!(
         %{
           root_chain_txhash: root_chain_txhash,
           log_index: log_index,
           decoded_utxo_position: decoded_utxo_position
         },
         event_type
       ) do
    root_chain_txhash_event = generate_root_chain_txhash_event(root_chain_txhash, log_index)

    ethevent =
      get(root_chain_txhash_event) ||
        %__MODULE__{
          root_chain_txhash_event: root_chain_txhash_event,
          log_index: log_index,
          root_chain_txhash: root_chain_txhash,
          event_type: event_type
        }

    tx_output = resolve_tx_output(%{utxo_pos: decoded_utxo_position})

    insert_exit_if_not_exist(ethevent, tx_output)
  end

  @spec resolve_tx_output(map()) :: %DB.TxOutput{} | nil
  defp resolve_tx_output(%{utxo_pos: utxo_pos}), do: DB.TxOutput.get_by_position(utxo_pos)

  @spec insert_exit_if_not_exist(%__MODULE__{}, %DB.TxOutput{} | nil) ::
          {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()} | :noop
  defp insert_exit_if_not_exist(_, nil), do: :noop

  defp insert_exit_if_not_exist(ethevent, tx_output) do
    # if TxOutput is already assiociated with this (or any other) spending event no action is needed
    if output_spend?(tx_output),
      do: :noop,
      else: do_insert_exit(ethevent, tx_output)
  end

  @spec do_insert_exit(%__MODULE__{}, %DB.TxOutput{}) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  defp do_insert_exit(ethevent, tx_output) when ethevent != nil and tx_output != nil do
    # sanity check
    false = output_spend?(tx_output)

    decoded_utxo_position = Utxo.position(tx_output.blknum, tx_output.txindex, tx_output.oindex)

    tx_output
    |> txoutput_changeset(%{child_chain_utxohash: generate_child_chain_utxohash(decoded_utxo_position)}, ethevent)
    |> DB.Repo.update()

    # a txoutput row just got updated, but we need to return the associated ethevent with all populated
    # fields including those populated by the DB (eg: inserted_at, updated_at, ...)
    {:ok, get(ethevent.root_chain_txhash_event)}
  end

  # Tells whether `TxOutput` was already spent
  # NOTE: it looks a little too deep into DB.TxOutput module, but I don't want to extent its API
  @spec output_spend?(%DB.TxOutput{}) :: boolean()
  defp output_spend?(%DB.TxOutput{spending_txhash: nil} = tx_output) do
    Enum.any?(tx_output.ethevents, & &1.event_type != :deposit)
  end

  defp output_spend?(%DB.TxOutput{}), do: true
end
