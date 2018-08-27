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

defmodule OMG.Watcher.EthEventDB do
  @moduledoc """
  Ecto schema for transaction's output (or input)
  """
  use Ecto.Schema

  alias OMG.API.Utxo
  alias OMG.Watcher.Repo
  alias OMG.Watcher.TxOutputDB

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  require Logger

  @field_names [:address, :currency, :amount, :blknum, :txindex, :oindex, :txbytes]
  def field_names, do: @field_names

  @primary_key {:hash, :binary, []}
  @derive {Phoenix.Param, key: :hash}
  schema "ethevents" do
    field :deposit_blknum, :integer
    field :deposit_txindex, :integer
    field :event_type, OMG.Watcher.Types.AtomType

    has_one :created_utxo, TxOutputDB, foreign_key: :creating_deposit
    has_one :exited_utxo, TxOutputDB, foreign_key: :spending_exit
  end

  @spec insert_deposit(binary(), pos_integer(), Utxo.t()) :: {:ok, any()}
  def insert_deposit(hash, blknum, %Utxo{owner: owner, currency: currency, amount: amount}) do
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

  def insert_exit(hash) do
    {:ok, _} =
      %__MODULE__{
        hash: hash,
        event_type: :exit
      }
      |> Repo.insert()
  end
end
