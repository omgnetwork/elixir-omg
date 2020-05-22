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

defmodule OMG.WatcherInfo.DB.Block.Chunk do
  @moduledoc """
  La chunk.
  """
  @max_params_count 0xFFFF
  # Prepares entries to the database in chunks to avoid `too many parameters` error.
  # Accepts the same parameters that `Repo.insert_all/3`.
  def chunk(entries) do
    utc_now = DateTime.utc_now()
    entries = Enum.map(entries, fn entry -> Map.merge(entry, %{inserted_at: utc_now, updated_at: utc_now}) end)

    chunk_size = entries |> hd() |> chunk_size()

    Stream.chunk_every(entries, chunk_size)
  end

  # Note: an entry with 0 fields will cause a divide-by-zero error.
  #
  # DB.Repo.chunk_size(%{}) ==> (ArithmeticError) bad argument in arithmetic expression
  #
  # But we could not think of a case where this code happen, so no defensive
  # checks here.
  defp chunk_size(entry), do: div(@max_params_count, fields_count(entry))

  defp fields_count(map), do: Kernel.map_size(map)
end
