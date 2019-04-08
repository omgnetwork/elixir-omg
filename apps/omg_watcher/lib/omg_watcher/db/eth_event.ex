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

defmodule OMG.Watcher.DB.EthEvent do
  @moduledoc """
  Ecto schema for events logged by Ethereum: deposits and exits
  """
  use Ecto.Schema

  alias OMG.Crypto
  alias OMG.Utxo
  alias OMG.Watcher.DB

  require Utxo

  @primary_key {:hash, :binary, []}
  @derive {Phoenix.Param, key: :hash}
  schema "ethevents" do
    field(:blknum, :integer)
    field(:txindex, :integer)
    field(:event_type, OMG.Watcher.DB.Types.AtomType)

    has_one(:created_utxo, DB.TxOutput, foreign_key: :creating_deposit)
    has_one(:exited_utxo, DB.TxOutput, foreign_key: :spending_exit)
  end

  def get(hash), do: DB.Repo.get(__MODULE__, hash)
  def get_all, do: DB.Repo.all(__MODULE__)

  @doc """
  Inserts deposits based on a list of event maps (if not already inserted before)
  """
  @spec insert_deposits!([OMG.State.Core.deposit()]) :: :ok
  def insert_deposits!(deposits) do
    deposits |> Enum.each(&insert_deposit!/1)
  end

  @spec insert_deposit!(OMG.State.Core.deposit()) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  defp insert_deposit!(%{blknum: blknum, owner: owner, currency: currency, amount: amount}) do
    {:ok, _} =
      if existing_deposit = get(deposit_key(blknum)) != nil,
        do: {:ok, existing_deposit},
        else:
          %__MODULE__{
            hash: deposit_key(blknum),
            blknum: blknum,
            txindex: 0,
            event_type: :deposit,
            created_utxo: %DB.TxOutput{
              blknum: blknum,
              txindex: 0,
              oindex: 0,
              owner: owner,
              currency: currency,
              amount: amount
            }
          }
          |> DB.Repo.insert()
  end

  @doc """
  Uses a list of encoded `Utxo.Position`s to insert the exits (if not already inserted before)
  """
  @spec insert_exits!([non_neg_integer()]) :: :ok
  def insert_exits!(exits) do
    exits
    |> Stream.map(&utxo_pos_from_exit_event/1)
    |> Enum.each(&insert_exit!/1)
  end

  @spec utxo_pos_from_exit_event(%{call_data: %{utxo_pos: pos_integer()}}) :: Utxo.Position.t()
  defp utxo_pos_from_exit_event(%{call_data: %{utxo_pos: utxo_pos}}), do: Utxo.Position.decode(utxo_pos)

  @spec insert_exit!(Utxo.Position.t()) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  defp insert_exit!(Utxo.position(blknum, txindex, _oindex) = position) do
    {:ok, _} =
      if existing_exit = get(exit_key(position)) != nil do
        {:ok, existing_exit}
      else
        utxo = DB.TxOutput.get_by_position(position)

        %__MODULE__{
          hash: exit_key(position),
          blknum: blknum,
          txindex: txindex,
          event_type: :exit,
          exited_utxo: utxo
        }
        |> DB.Repo.insert()
      end
  end

  @doc """
  Good candidate for deposit/exit primary key is a pair (Utxo.position, event_type).
  Switching to composite key requires careful consideration of data types and schema change,
  so for now, we'd go with artificial key
  """
  @spec generate_unique_key(Utxo.Position.t(), :deposit | :exit) :: OMG.Crypto.hash_t()
  def generate_unique_key(position, type) do
    "<#{position |> Utxo.Position.encode()}:#{type}>" |> Crypto.hash()
  end

  defp deposit_key(blknum), do: generate_unique_key(Utxo.position(blknum, 0, 0), :deposit)
  defp exit_key(position), do: generate_unique_key(position, :exit)
end
