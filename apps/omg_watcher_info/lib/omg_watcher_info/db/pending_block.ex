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

defmodule OMG.WatcherInfo.DB.PendingBlock do
  @moduledoc """
  Ecto schema for pending block data
  These are valid block data received by the internal bus that should be stored in the database.
  This intermediate table is needed as the messages received by the bus are not persisted
  and if for some reason the writing to the database fails, we would lose these data.
  """
  use Ecto.Schema
  use OMG.Utils.LoggerExt

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias OMG.WatcherInfo.DB

  @type pending_block() :: %{
          blknum: pos_integer(),
          data: binary(),
          retry_count: non_neg_integer(),
          status: String.t()
        }

  @status_pending "pending"
  @status_processing "processing"
  @status_done "done"

  @primary_key {:blknum, :integer, []}

  def status_pending, do: @status_pending
  def status_processing, do: @status_processing
  def status_done, do: @status_done

  schema "pending_blocks" do
    field(:data, :binary)
    field(:status, :string, default: @status_pending)
    field(:retry_count, :integer, default: 0)

    timestamps(type: :utc_datetime_usec)
  end

  @spec insert(map()) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  def insert(params) do
    params
    |> insert_changeset()
    |> DB.Repo.insert()
  end

  def update(block, params) do
    block
    |> update_changeset(params)
    |> DB.Repo.update()
  end

  def update_changeset(pending_block, params) do
    cast(pending_block, params, [:status, :retry_count])
  end

  @spec get_next_to_process() :: nil | %__MODULE__{}
  def get_next_to_process() do
    @status_processing
    |> query_next_with_status()
    |> DB.Repo.one()
    |> case do
      nil ->
        @status_pending
        |> query_next_with_status()
        |> DB.Repo.one()

      _ ->
        nil
    end
  end

  defp query_next_with_status(status) do
    from(
      pending_block in __MODULE__,
      where: [status: ^status],
      order_by: :blknum
    )
  end

  defp insert_changeset(params) do
    %__MODULE__{}
    |> cast(params, [:blknum, :data])
    |> unique_constraint(:blknum, name: :pending_blocks_pkey)
  end
end
