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

defmodule OMG.ChildChain.Integration.FeeServer do
  @moduledoc """
  Tests a simple happy path of all the pieces working together
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias OMG.ChildChain.FeeServer
  alias OMG.Eth
  alias OMG.TestHelper

  @moduletag :integration
  @moduletag :child_chain

  @eth Eth.zero_address()
  @eth_hex Eth.Encoding.to_hex(@eth)
  @fees %{@eth_hex => 0}

  setup do
    ignore_option = Application.fetch_env!(:omg_child_chain, :ignore_fees)
    old_file_name = Application.fetch_env!(:omg_child_chain, :fee_specs_file_name)

    {:ok, file_path, file_name} = TestHelper.write_fee_file(@fees)
    Application.put_env(:omg_child_chain, :fee_specs_file_name, file_name)

    on_exit(fn ->
      File.rm(file_path)
      Application.put_env(:omg_child_chain, :ignore_fees, ignore_option)
      Application.put_env(:omg_child_chain, :fee_specs_file_name, old_file_name)

      # without waiting tests interfere on :ets
      Process.sleep(500)
    end)

    %{fee_file: file_name}
  end

  describe "fees in effect" do
    test "corrupted file does not make server crash", %{fee_file: file_name} do
      {:started, _log, exit_fn} = start_fee_server()

      default_fees = %{@eth => 0}
      new_fee = 5

      assert {:ok, default_fees} == FeeServer.transaction_fees()

      # corrupt file, refresh, check fees did not change
      overwrite_fee_file(file_name, "[not a json]")
      assert refresh_fees() =~ ~r/\[error\].*Unable to update fees/

      assert {:ok, default_fees} == FeeServer.transaction_fees()
      assert server_alive?()

      # fix file, reload, check changes applied
      overwrite_fee_file(file_name, %{@eth_hex => new_fee})
      refresh_fees()

      assert {:ok, %{@eth => new_fee}} == FeeServer.transaction_fees()
      assert server_alive?()

      exit_fn.()
    end

    test "starting with corrupted file makes server die", %{fee_file: file_name} do
      overwrite_fee_file(file_name, "[not a json]")
      {:died, log} = start_fee_server()

      assert log =~ ~r/\[error\].*Unable to update fees/
      assert false == server_alive?()
    end
  end

  describe "fees ignored" do
    setup do
      Application.put_env(:omg_child_chain, :ignore_fees, true)
      {:started, log, exit_fn} = start_fee_server()
      assert log =~ "ignored"

      on_exit(fn ->
        exit_fn.()
        Application.put_env(:omg_child_chain, :ignore_fees, false)
      end)

      :ok
    end

    test "fee server ignores file updates" do
      assert {:ok, :ignore} == FeeServer.transaction_fees()

      assert refresh_fees() =~ "Updates takes no effect"

      assert {:ok, :ignore} == FeeServer.transaction_fees()
      assert server_alive?()
    end
  end

  defp start_fee_server do
    log = capture_log(fn -> GenServer.start(FeeServer, [], name: TestFeeServer) end)

    case GenServer.whereis(TestFeeServer) do
      pid when is_pid(pid) ->
        # switch of internal timer to don't interfere with tests
        if tref = Keyword.get(:sys.get_state(TestFeeServer), :tref) do
          {:ok, :cancel} = :timer.cancel(tref)
        end

        {:started, log, fn -> GenServer.stop(pid) end}

      nil ->
        {:died, log}
    end
  end

  defp refresh_fees do
    pid = GenServer.whereis(TestFeeServer)

    capture_log(fn ->
      Process.send(pid, :update_fee_spec, [])
      # handle_info is async - we need to wait it executes to get message logged
      Process.sleep(100)
    end)
  end

  defp server_alive? do
    case GenServer.whereis(TestFeeServer) do
      pid when is_pid(pid) ->
        Process.alive?(pid)

      _ ->
        false
    end
  end

  defp overwrite_fee_file(file, content) do
    # file modification date is in seconds
    Process.sleep(1000)
    {:ok, _, ^file} = TestHelper.write_fee_file(content, file)
  end
end
