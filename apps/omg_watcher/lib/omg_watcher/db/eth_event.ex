# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.DB.EthEvent do
  @moduledoc """
  Ecto schema for events logged by Ethereum
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias OMG.Crypto
  alias OMG.Eth.Encoding
  alias OMG.Utxo
  alias OMG.Watcher.DB

  require Utxo

  @primary_key false
  schema "ethevents" do
    field(:root_chain_txhash, :binary, primary_key: true)
    field(:event_type, OMG.Watcher.DB.Types.AtomType, primary_key: true)

    field(:root_chain_txhash_event, :binary)

    many_to_many(
      :txoutputs,
      DB.TxOutput,
      join_through: "ethevents_txoutputs",
      join_keys: [root_chain_txhash_event: :root_chain_txhash_event, child_chain_utxohash: :child_chain_utxohash]
    )

    timestamps([type: :utc_datetime])
  end

  @doc """
  Inserts deposits based on a list of event maps (if not already inserted before)
  """
  @spec insert_deposits!([OMG.State.Core.deposit()]) :: :ok
  def insert_deposits!(deposits) do
    deposits |> Enum.each(&insert_deposit!/1)
  end

  @spec insert_deposit!(OMG.State.Core.deposit()) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  defp insert_deposit!(%{root_chain_txhash: root_chain_txhash, blknum: blknum, owner: owner, currency: currency, amount: amount}) do
    event_type = :deposit
    position = Utxo.position(blknum, 0, 0)
    root_chain_txhash_event = generate_root_chain_txhash_event(root_chain_txhash, event_type)

    case get(root_chain_txhash_event) do
      nil ->
        %__MODULE__{
          root_chain_txhash_event: root_chain_txhash_event,
          root_chain_txhash: root_chain_txhash,
          event_type: :deposit,

          # a deposit from the root chain will only ever have 1 childchain txoutput object
          txoutputs: [%DB.TxOutput{
            child_chain_utxohash: generate_child_chain_utxohash(position),
              blknum: blknum,
              txindex: 0,
              oindex: 0,
              owner: owner,
              currency: currency,
              amount: amount
            }]
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
  @spec insert_exits!([non_neg_integer()]) :: :ok
  def insert_exits!(exits) do
    exits
    |> Stream.map(&utxo_exit_from_exit_event/1)
    |> Enum.each(&insert_exit!/1)
  end

  @spec utxo_exit_from_exit_event(%{call_data: %{utxo_pos: pos_integer()}, root_chain_txhash: charlist()})
      :: %{root_chain_txhash: binary(), decoded_utxo_position: Utxo.Position.t()}
  defp utxo_exit_from_exit_event(%{call_data: %{utxo_pos: utxo_pos}, root_chain_txhash: root_chain_txhash}) do
    %{root_chain_txhash: root_chain_txhash, decoded_utxo_position: Utxo.Position.decode!(utxo_pos)}
  end

  @spec insert_exit!(%{root_chain_txhash: binary(), decoded_utxo_position: Utxo.Position.t()})
      :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  defp insert_exit!(%{root_chain_txhash: root_chain_txhash, decoded_utxo_position: decoded_utxo_position}) do
    event_type = :standard_exit
    root_chain_txhash_event = generate_root_chain_txhash_event(root_chain_txhash, event_type)

    case get(root_chain_txhash_event) do
      nil ->
        ethevent = %__MODULE__{
          root_chain_txhash_event: root_chain_txhash_event,
          root_chain_txhash: root_chain_txhash,
          event_type: :standard_exit
        }

        DB.TxOutput.get_by_position(decoded_utxo_position)
        |> DB.Repo.preload(:ethevents)
        |> txoutput_changeset(%{child_chain_utxohash: generate_child_chain_utxohash(decoded_utxo_position)}, ethevent)
        |> DB.Repo.update()

        # a txoutput row just got updated, but we need to return the associated ethevent with all populated
        # fields including those populated by the DB (eg: inserted_at, updated_at, ...)
        {:ok, get(root_chain_txhash_event)}

      existing_exit ->
        {:ok, existing_exit}
    end
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

  defp generate_root_chain_txhash_event(root_chain_txhash, event_type) do
    Encoding.to_hex(root_chain_txhash) <> Atom.to_string(event_type) |> Crypto.hash()
  end

  defp get(root_chain_txhash_event), do: DB.Repo.get_by(__MODULE__, root_chain_txhash_event: root_chain_txhash_event)
end
