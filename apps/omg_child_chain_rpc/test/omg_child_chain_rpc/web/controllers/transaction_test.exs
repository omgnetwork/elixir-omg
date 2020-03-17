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

defmodule OMG.ChildChainRPC.Web.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.ChildChainRPC.Web.TestHelper
  @table_name :alarms
  setup_all do
    {:ok, pid} = setup_server()

    on_exit(fn ->
      teardown_server(pid)
    end)

    :ok
  end

  test "transaction.submit endpoint rejects request without parameter" do
    missing_param = %{}

    assert %{
             "success" => false,
             "data" => %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "transaction",
                   "validator" => ":hex"
                 }
               }
             }
           } = TestHelper.rpc_call(:post, "/transaction.submit", missing_param)
  end

  test "transaction.submit endpoint rejects request with non hex transaction" do
    assert %{
             "success" => false,
             "data" => %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "transaction",
                   "validator" => ":hex"
                 }
               }
             }
           } = TestHelper.rpc_call(:post, "/transaction.submit", %{transaction: "hello"})
  end

  defp setup_server() do
    {:ok, pid} = OMG.ChildChainRPC.Application.start([], [])
    _ = Application.load(:omg_child_chain_rpc)
    table_setup()

    {:ok, pid}
  end

  defp teardown_server(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _, _} ->
        # a tiny wait to allow the endpoint to be brought down for good, not sure how to get rid of the sleep
        # without it one might get `eaddrinuse`
        Process.sleep(10)
        :ok
    end
  end

  defp table_setup() do
    case :ets.info(@table_name) do
      :undefined ->
        @table_name = :ets.new(@table_name, table_settings())

      _ ->
        # we have to cleanup the owner of the alarms table which is alarm_handler part of sasl, check omg_status
        :ok = Application.stop(:sasl)
        table_setup()
    end
  end

  defp table_settings(), do: [:named_table, :set, :protected, read_concurrency: true]
end
