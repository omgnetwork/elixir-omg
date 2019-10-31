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

defmodule OMG.Performance.ExtendedPerftest do
  use OMG.Utils.LoggerExt

  alias OMG.TestHelper
  alias OMG.Utxo
  alias Support.Integration.DepositHelper

  require Utxo

  @doc """
  Runs test with {ntx_to_send} transactions for each {spenders}.
  Initial deposits for each account will be made on passed {contract_addr}.

  Default options:
  ```
  %{
    destdir: ".", # directory where the results will be put
    geth: System.get_env("ETHEREUM_RPC_URL"),
    child_chain: "http://localhost:9656"
  }
  ```
  """
  @spec start(pos_integer(), list(TestHelper.entity()), map()) :: :ok
  def start(ntx_to_send, spenders, opts \\ %{}) do
    _ =
      Logger.info(
        "Number of spenders: #{inspect(length(spenders))}, number of tx to send per spender: #{inspect(ntx_to_send)}" <>
          ", #{inspect(length(spenders) * length(ntx_to_send))} txs in total"
      )

    defaults = %{destdir: "."}

    opts = Map.merge(defaults, opts)

    utxos = create_deposits(spenders, ntx_to_send)

    # FIXME: the way the profile option is handled is super messy - clean this here and in simple perftest
    #        actually, profiling makes no sense here, so maybe un-allowit
    {:ok, data} = OMG.Performance.Runner.run({ntx_to_send, utxos, opts, false})
    _ = Logger.info("#{inspect(data)}")
  end

  @spec create_deposits(list(TestHelper.entity()), pos_integer()) :: list()
  defp create_deposits(spenders, ntx_to_send) do
    make_deposits(10 * ntx_to_send, spenders)
    |> Enum.map(fn {:ok, owner, blknum, amount} ->
      utxo_pos = Utxo.position(blknum, 0, 0) |> Utxo.Position.encode()
      %{owner: owner, utxo_pos: utxo_pos, amount: amount}
    end)
  end

  defp make_deposits(value, accounts) do
    depositing_f = fn account ->
      deposit_blknum = DepositHelper.deposit_to_child_chain(account.addr, value)

      {:ok, account, deposit_blknum, value}
    end

    accounts
    |> Enum.map(&Task.async(fn -> depositing_f.(&1) end))
    |> Enum.map(fn task -> Task.await(task, :infinity) end)
  end
end
