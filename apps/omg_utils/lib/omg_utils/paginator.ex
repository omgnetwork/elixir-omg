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
defmodule OMG.Utils.Paginator do
  @moduledoc """
  Wraps resulted query data along with pagination information used.
  """

  @default_limit 200
  @first_page 1

  @type t(data_type) :: %__MODULE__{
          data: list(data_type),
          data_paging: %{limit: pos_integer(), page: pos_integer()}
        }

  defstruct data: [],
            data_paging: %{
              limit: @default_limit,
              page: @first_page
            }

  @doc """
  Creates new paginator from query constraints like [limit: 200, page: 1], none of keys is required.
  """
  @spec from_constraints(Keyword.t(), integer()) :: %__MODULE__{:data => [], :data_paging => map()}
  def from_constraints(constraints, max_limit) when is_integer(max_limit) do
    data_paging =
      constraints
      |> Keyword.take([:page, :limit])
      |> Keyword.put_new(:page, @first_page)
      |> Keyword.update(:limit, max_limit, &min(&1, max_limit))
      |> Map.new()

    %__MODULE__{data: [], data_paging: data_paging}
  end

  @spec set_data(list(), t()) :: t()
  def set_data(data, paginator) when is_list(data), do: %__MODULE__{paginator | data: data}
end
