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

defmodule OMG.WatcherInfo.DB.Repo do
  use Ecto.Repo,
    otp_app: :omg_watcher_info,
    adapter: Ecto.Adapters.Postgres

  @max_params_count 0xFFFF
  def max_params_count(), do: @max_params_count

  @doc """
  Inserts all entries to the database in chunks to avoid `too many parameters` error.
  Accepts the same parameters that `Repo.insert_all/3`.
  """
  @spec insert_all_chunked(
          schema_or_source :: binary() | atom() | Ecto.Schema.t(),
          entries :: [map() | Keyword.t()],
          opts :: Keyword.t()
        ) :: :ok
  def insert_all_chunked(schema_or_source, entries, opts \\ [])

  def insert_all_chunked(_schema_or_source, [], _opts), do: :ok

  def insert_all_chunked(schema_or_source, entries, opts) do
    utc_now = DateTime.utc_now()
    entries = Enum.map(entries, fn entry -> Map.merge(entry, %{inserted_at: utc_now, updated_at: utc_now}) end)

    chunk_size = chunk_size(entries |> hd)

    entries
    |> Stream.chunk_every(chunk_size)
    |> Enum.each(&insert_all(schema_or_source, &1, opts))
  end

  # Note: an entry with 0 fields will cause a divide-by-zero error.
  #
  # DB.Repo.chunk_size(%{}) ==> (ArithmeticError) bad argument in arithmetic expression
  #
  # Do we want/need to be that defensive?
  def chunk_size(entry) do
    @max_params_count |> div(entry |> fields_count)
  end

  defp fields_count(map) when is_map(map), do: map |> Kernel.map_size()
  defp fields_count(list) when is_list(list), do: length(list)
end
