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

defmodule LoadTest.Performance do
  @moduledoc """
  OMG network performance tests. Provides general setup and utilities to do the perf tests.
  """

  defmacro __using__(_opt) do
    quote do
      alias LoadTest.Common.ByzantineEvents
      alias LoadTest.Common.ExtendedPerftest
      alias LoadTest.Common.Generators

      alias LoadTest.Performance

      import Performance, only: [timeit: 1]
      require Performance
      require Logger

      :ok
    end
  end

  def init() do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, _} = Application.ensure_all_started(:ethereumex)
    {:ok, _} = Application.ensure_all_started(:hackney)
    {:ok, _} = Application.ensure_all_started(:cowboy)
    :ok
  end

  @doc """
  Utility macro which causes the expression given to be timed, the timing logged (`info`) and the original result of the
  call to be returned

  ## Examples

    iex> use LoadTest.Performance
    iex> timeit 1+2
    3
  """
  defmacro timeit(call) do
    quote do
      {duration, result} = :timer.tc(fn -> unquote(call) end)
      duration_s = duration / 1_000_000
      _ = Logger.info("Lasted #{inspect(duration_s)} seconds")
      result
    end
  end
end
