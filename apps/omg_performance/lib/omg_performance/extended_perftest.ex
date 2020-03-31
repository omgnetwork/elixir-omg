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

defmodule OMG.Performance.ExtendedPerftest do
  @moduledoc """
  This performance test allows to send out many transactions to a child chain instance of choice.

  See `OMG.Performance` for configuration within the `iex` shell using `Performance.init()`
  """

  use OMG.Utils.LoggerExt

  alias OMG.TestHelper
  alias OMG.Utxo
  alias Support.Integration.DepositHelper

  require Utxo

  @make_deposit_timeout 600_000

  @doc """
  Runs test with `ntx_to_send` transactions for each of `spenders` provided.
  The spenders should be provided in the form as given by `OMG.Performance.Generators.generate_users`, and must be
  funded on the root chain. The test invocation will do the deposits on the child chain.

  ## Usage

  Once you have your Ethereum node and a child chain running, from a configured `iex -S mix run --no-start` shell

  ```
  use OMG.Performance

  Performance.init()
  spenders = Generators.generate_users(2)
  Performance.ExtendedPerftest.start(100, spenders, destdir: destdir)
  ```

  The results are going to be waiting for you in a file within `destdir` and will be logged.

  Options:
    - :destdir - directory where the results will be put, relative to `pwd`, defaults to `"."`
    - :randomized - whether the non-change outputs of the txs sent out will be random or equal to sender (if `false`),
      defaults to `true`
  """
  @spec start(pos_integer(), list(TestHelper.entity()), keyword()) :: :ok
  def start(ntx_to_send, spenders, opts \\ []) do
    _ =
      Logger.info(
        "Number of spenders: #{inspect(length(spenders))}, number of tx to send per spender: #{inspect(ntx_to_send)}" <>
          ", #{inspect(length(spenders) * ntx_to_send)} txs in total"
      )

    defaults = [destdir: "."]

    opts = Keyword.merge(defaults, opts)

    utxos = create_deposits(spenders, ntx_to_send)

    OMG.Performance.Runner.run(ntx_to_send, utxos, opts, false)
  end

  @spec create_deposits(list(TestHelper.entity()), pos_integer()) :: list()
  defp create_deposits(spenders, ntx_to_send) do
    Enum.map(make_deposits(ntx_to_send * 2, spenders), fn {:ok, owner, blknum, amount} ->
      utxo_pos = Utxo.Position.encode(Utxo.position(blknum, 0, 0))
      %{owner: owner, utxo_pos: utxo_pos, amount: amount}
    end)
  end

  defp make_deposits(value, accounts) do
    depositing_f = fn account ->
      deposit_blknum = DepositHelper.deposit_to_child_chain(account.addr, value)
      {:ok, account, deposit_blknum, value}
    end

    accounts
    |> Task.async_stream(depositing_f, timeout: @make_deposit_timeout, max_concurrency: 10_000)
    |> Enum.map(fn {:ok, result} -> result end)
  end
end
