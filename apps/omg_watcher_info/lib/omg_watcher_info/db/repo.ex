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

  import Ecto.Query

  @max_params_count 0xFFFF

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
    chunk_size = @max_params_count |> div(entries |> hd |> fields_count)

    utc_now = DateTime.utc_now()

    entries
    |> Enum.map(fn entry ->
      Map.merge(entry, %{inserted_at: utc_now, updated_at: utc_now})
    end)
    |> Stream.chunk_every(chunk_size)
    |> Enum.each(&insert_all(schema_or_source, &1, opts))
  end

  @doc """
  The functions fetch/1, fetch/2 and fetch_by/2 are added here to provide a consistent Ecto.Repo interface.
  The Ecto.Repo interface provides functions like: get/3, get_by/2, one/2. They all return `nil` if nothing
  is found and raise an exception if more than one entry was found.

  These return values are very different from functions like delete/2, insert/2, and update/2 which return:
    success -> {:ok, Ecto.Schema.t()}
    failure -> {:error, Ecto.Changeset.t()}}

  Also to fetch/1, fetch_by/2 play nicely with the Ecto.Multi pipelines which expects each stage of the
  pipeline to return:
    success -> {:ok, value}
    failure -> {:error, value}
  """
  def fetch(query) do
    case all(query) do
      [] ->
        {:error, query}

      [obj] ->
        {:ok, obj}

      _ ->
        raise "Expected one or no items, got many items #{inspect(query)}"
    end
  end

  def fetch_by(query, args) do
    query
    |> where(^args)
    |> fetch
  end

  defp fields_count(map) when is_map(map), do: map |> Kernel.map_size()
  defp fields_count(list) when is_list(list), do: length(list)
end
