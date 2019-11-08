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

defmodule Support.WaitFor do
  @moduledoc """
  Generic wait_for_* utils, styled after web3 counterparts
  """

  alias OMG.Eth.Encoding
  alias __MODULE__

  def eth_rpc(timeout \\ 10_000) do
    f = fn ->
      case Ethereumex.HttpClient.eth_syncing() do
        {:ok, false} ->
          {:ok, :ready}

        _ ->
          :repeat
      end
    end

    WaitFor.ok(f, timeout)
  end

  @doc """
  NOTE: `eth_receipt` takes txhash as raw decoded binary, like the rest of Eth APIs, but binaries in the receipt
  returned are in `0xhex-style`

  This is low-level, consider using `|> Support.DevHelper.transact_sync!()` for eth-transactions' syncronicity in tests
  """
  def eth_receipt(txhash, timeout \\ 15_000) do
    f = fn ->
      txhash
      |> Encoding.to_hex()
      |> Ethereumex.HttpClient.eth_get_transaction_receipt()
      |> case do
        {:ok, receipt} when receipt != nil -> {:ok, receipt}
        _ -> :repeat
      end
    end

    WaitFor.ok(f, timeout)
  end

  # Repeats f until f returns {:ok, ...}, :ok OR exception is raised (see :erlang.exit, :erlang.error) OR timeout
  # after `timeout` milliseconds specified
  #
  # Simple throws and :badmatch are treated as signals to repeat
  def ok(f, timeout \\ 5_000) do
    fn -> repeat_until_ok(f) end
    |> Task.async()
    |> Task.await(timeout)
  end

  defp repeat_until_ok(f) do
    Process.sleep(100)

    try do
      case f.() do
        :ok = return -> return
        {:ok, _} = return -> return
        _ -> repeat_until_ok(f)
      end
    catch
      _something -> repeat_until_ok(f)
      :error, {:badmatch, _} = _error -> repeat_until_ok(f)
    end
  end
end
