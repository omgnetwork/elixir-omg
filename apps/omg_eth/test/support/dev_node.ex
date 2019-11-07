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

defmodule Support.DevNode do
  @moduledoc """
  Common library for running geth and parity in dev mode.
  """
  require Logger

  def start do
    start(backend())
  end

  defp start(:geth) do
    OMG.Eth.DevGeth.start()
  end

  defp start(:parity) do
    Support.DevParity.start()
  end

  defp start(:ganache) do
    {:ok, _} = Application.ensure_all_started(:ethereumex)
    # we won't start ganache for the testing user, so we want to warn in case this was expected
    false = Application.get_env(:omg_eth, :run_test_eth_dev_node) && {:error, :ganache_must_be_already_started}
    {:ok, fn -> :ok end}
  end

  def wait_for_start(outstream, look_for, timeout, logger_fn \\ &default_logger/1) do
    # Monitors the stdout coming out of a process for signal of successful startup
    waiting_task_function = fn ->
      outstream
      |> Stream.map(logger_fn)
      |> Stream.take_while(fn line -> not String.contains?(line, look_for) end)
      |> Enum.to_list()
    end

    waiting_task_function
    |> Task.async()
    |> Task.await(timeout)

    :ok
  end

  def default_logger(line) do
    _ = Logger.debug("eth node: " <> line)
    line
  end

  defp backend() do
    Application.fetch_env!(:omg_eth, :eth_node)
  end
end
