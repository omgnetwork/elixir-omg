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

defmodule OMG.Performance do
  @moduledoc """
  OMG network child chain server performance test entrypoint. Setup and runs performance tests.

  # Usage

  See functions in this module for options available

  ## start_simple_perftest runs test with 5 transactions for each 3 senders and default options.

  ```
  mix run --no-start -e 'OMG.Performance.start_simple_perftest(5, 3)'
  ```

  ## start_extended_perftest runs test with 100 transactions for one specified account and default options.
  ## extended test is run on testnet make sure you followed instruction in `README.md` and both `geth` and `omg_child_chain` are running

  ```
  mix run --no-start -e 'OMG.Performance.start_extended_perftest(100, [%{ addr: <<192, 206, 18, ...>>, priv: <<246, 22, 164, ...>>}], "0xbc5f ...")'
  ```

  ## Parameters passed are: 1. number of transaction each sender will send, 2. list of senders (see: TestHelper.generate_entity()) and 3. `contract` address

  # Note:

  `:fprof` will print a warning:
  ```
  Warning: {erlang, trace, 3} called in "<0.514.0>" - trace may become corrupt!
  ```
  It is caused by using `procs: :all` in options. So far we're not using `:erlang.trace/3` in our code,
  so it has been ignored. Otherwise it's easy to reproduce and report if anyone has the nerve
  (github.com/erlang/otp and the JIRA it points you to).

  # FIXME this function was removed, re-edit the docs here

  ## start_standard_exit_perftest runs test that fetches standard exit data from the Watcher
  ## standard_exit_perftest is run on testnet make sure you followed instruction in `README.md` and `geth`,
  ## `omg_childchain` & `omg_watcher` are running.

  ```
  mix run --no-start -e 'OMG.Performance.start_standard_exit_perftest([%{ addr: <<192, 206, 18, ...>>, priv: <<246, 22, 164, ...>>}], 3, "0xbc5f ...")'
  ```

  ## Parameters passed are: 1. list of senders, 2. number of users that fetching exits in parallel, 3. contract address
  With default options, number of transactions sent to the network is 10 times the senders count per each sender
  Number of exiting utxo is total number of transactions, each exiting user ask for the same utxo set, but mixes the order.
  """

  # FIXME docs
  # FIXME map to keyword for opts everywhere
  def init(opts \\ %{}) do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, _} = Application.ensure_all_started(:ethereumex)
    {:ok, _} = Application.ensure_all_started(:hackney)
    {:ok, _} = Application.ensure_all_started(:cowboy)

    child_chain_url =
      System.get_env("CHILD_CHAIN_URL") || Application.get_env(:omg_watcher, :child_chain_url, "http://localhost:9656")

    ethereum_rpc_url =
      System.get_env("ETHEREUM_RPC_URL") || Application.get_env(:ethereumex, :url, "http://localhost:8545")

    defaults = %{
      ethereum_rpc_url: ethereum_rpc_url,
      child_chain_url: child_chain_url,
      contract_addr: nil
    }

    opts = Map.merge(defaults, opts)

    :ok = Application.put_env(:ethereumex, :request_timeout, :infinity)
    :ok = Application.put_env(:ethereumex, :http_options, recv_timeout: :infinity)
    :ok = Application.put_env(:ethereumex, :url, opts[:ethereum_rpc_url])

    :ok =
      if opts[:contract_addr],
        do: Application.put_env(:omg_eth, :contract_addr, OMG.Eth.RootChain.contract_map_to_hex(opts[:contract_addr])),
        else: :ok

    :ok = Application.put_env(:omg_watcher, :child_chain_url, opts[:child_chain_url])

    :ok
  end
end
