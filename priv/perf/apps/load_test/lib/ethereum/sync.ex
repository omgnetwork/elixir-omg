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

defmodule LoadTest.Ethereum.Sync do
  @moduledoc """
  Utility module for repeating a function call until a given criteria is met.
  """
  @sleep_interval_ms 100

  @doc """
  Repeats f until f returns {:ok, ...}, :ok OR exception is raised (see :erlang.exit, :erlang.error) OR timeout
  after `timeout` milliseconds specified

  Simple throws and :badmatch are treated as signals to repeat
  """
  def repeat_until_success(f, timeout) do
    fn -> do_repeat_until_success(f) end
    |> Task.async()
    |> Task.await(timeout)
  end

  defp do_repeat_until_success(f) do
    Process.sleep(@sleep_interval_ms)

    try do
      case f.() do
        :ok = return -> return
        {:ok, _} = return -> return
        _ -> do_repeat_until_success(f)
      end
    catch
      _ -> do_repeat_until_success(f)
      :error, {:badmatch, _} -> do_repeat_until_success(f)
    end
  end
end
