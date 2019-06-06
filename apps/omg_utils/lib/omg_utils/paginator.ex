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

  @type t() :: %__MODULE__{
          data: list(),
          data_paging: %{limit: pos_integer(), page: pos_integer()}
        }

  defstruct data: [],
            data_paging: %{
              limit: @default_limit,
              page: @first_page
            }

  @doc """

  """
  @spec from_constrains(Keyword.t(), pos_integer) :: {t(), Keyword.t()}
  def from_constrains(opts, max_limit) when max_limit > 0 do
    paginator = new(opts, max_limit)

    {
      paginator,
      opts
      |> Keyword.drop([:page])
      |> Keyword.put(:limit, paginator.data_paging.limit)
      |> Keyword.put_new(:offset, offset(paginator))
    }
  end

  @spec set_data(list(), t()) :: t()
  def set_data(data, paginator) when is_list(data), do: %__MODULE__{paginator | data: data}

  @spec new(Keyword.t(), any) :: t()
  defp new(constrains, max_limit) do
    %{page: _, limit: _} =
      data_paging =
      constrains
      |> Keyword.take([:page, :limit])
      |> Keyword.put_new(:page, @first_page)
      |> Keyword.update(:limit, max_limit, &min(&1, max_limit))
      |> Map.new()

    %__MODULE__{data_paging: data_paging}
  end

  @spec offset(t()) :: non_neg_integer()
  defp offset(%__MODULE__{data_paging: %{limit: limit, page: page}}), do: (page - 1) * limit
end
