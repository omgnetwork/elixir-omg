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
defmodule OMG.Utils.Paginator do
  @moduledoc """
  Wraps resulted query data along with pagination information used.
  """

  @default_limit 200
  @first_page 1

  defstruct data: [],
            data_paging: %{
              limit: @default_limit,
              page: @first_page
            }

  @doc """

  """
  @spec from_constrains(Keyword.t(), pos_integer) :: {%__MODULE__{}, Keyword.t()}
  def from_constrains(opts, max_limit) do
    {
      %__MODULE__{},
      opts |>  Keyword.update(:limit, max_limit, &min(&1, max_limit))
    }
  end

  def set_data(data, paginator), do: %__MODULE__{paginator | data: data}
end
