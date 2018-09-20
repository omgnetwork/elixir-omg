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

defmodule OMG.Watcher.DB.EthEventDB do
  @moduledoc """
  Ecto schema for transaction's output (or input)
  """
  use Ecto.Schema

  alias OMG.Watcher.DB.Repo
  alias OMG.Watcher.DB.TxOutputDB

  @primary_key {:hash, :binary, []}
  @derive {Phoenix.Param, key: :hash}
  schema "ethevents" do
    field(:deposit_blknum, :integer)
    field(:deposit_txindex, :integer)
    field(:event_type, OMG.Watcher.DB.Types.AtomType)

    has_one(:created_utxo, TxOutputDB, foreign_key: :creating_deposit)
    has_one(:exited_utxo, TxOutputDB, foreign_key: :spending_exit)
  end

  def get(hash), do: Repo.get(__MODULE__, hash)
  def get_all, do: Repo.all(__MODULE__)

  @spec insert_deposits([map()]) :: [{:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}]
  def insert_deposits(deposits) do
    deposits
    |> Enum.map(fn %{hash: hash, blknum: blknum, owner: owner, currency: currency, amount: amount} ->
      insert_deposit(hash, blknum, owner, currency, amount)
    end)
  end

  @spec insert_deposit(binary(), pos_integer(), binary(), binary(), pos_integer()) ::
          {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  defp insert_deposit(hash, blknum, owner, currency, amount) do
    {:ok, _} =
      %__MODULE__{
        hash: hash,
        deposit_blknum: blknum,
        deposit_txindex: 0,
        event_type: :deposit,
        created_utxo: %TxOutputDB{
          owner: owner,
          currency: currency,
          amount: amount
        }
      }
      |> Repo.insert()
  end
end
