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

defmodule OMG.ChildChain.Integration.FeeServerTest do
  @moduledoc false

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
  @not_eth <<1::size(160)>>
  @not_eth_hex Eth.Encoding.to_hex(@not_eth)
  @payment_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v1)

  @fees %{
    @payment_tx_type => %{
      @eth_hex => %{
        amount: 1,
        pegged_amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_unix!(1_546_336_800)
      },
      @not_eth_hex => %{
        amount: 2,
        pegged_amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_unix!(1_546_336_800)
      }
    },
    2 => %{
      @eth_hex => %{
        amount: 1,
        pegged_amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_unix!(1_546_336_800)
      }
    }
  }

  @parsed_fees %{
    @payment_tx_type => %{
      @eth => %{
        amount: 1,
        pegged_amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_unix!(1_546_336_800)
      },
      @not_eth => %{
        amount: 2,
        pegged_amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_unix!(1_546_336_800)
      }
    },
    2 => %{
      @eth => %{
        amount: 1,
        pegged_amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_unix!(1_546_336_800)
      }
    }
  }

  setup do
    {:ok, apps} = Application.ensure_all_started(:omg_status)

    # make sure :ets managed to clear up before we start another
    Stream.repeatedly(fn ->
      Process.sleep(25)
      :undefined == :ets.info(:fees_bucket)
    end)
    |> Enum.take_while(fn b -> not b end)

    old_file_path = Application.fetch_env!(:omg_child_chain, :fee_specs_file_path)
    old_file_name = Application.fetch_env!(:omg_child_chain, :fee_specs_file_name)

    {:ok, file_path, file_name} = TestHelper.write_fee_file(@fees)

    Application.put_env(:omg_child_chain, :fee_specs_file_path, file_path)
    Application.put_env(:omg_child_chain, :fee_specs_file_name, file_name)

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(fn app -> Application.stop(app) end)

      :ok =
        file_path
        |> Path.join(file_name)
        |> File.rm()

      Application.put_env(:omg_child_chain, :fee_specs_file_path, old_file_path)
      Application.put_env(:omg_child_chain, :fee_specs_file_name, old_file_name)
    end)

    %{fee_file_path: file_path, fee_file_name: file_name}
  end

  describe "fees in effect" do
    test "corrupted file does not make server crash", %{fee_file_path: file_path, fee_file_name: file_name} do
      {:started, _log, exit_fn} = start_fee_server()

      new_fee = %{
        amount: 5,
        subunit_to_unit: 100,
        pegged_amount: 2,
        pegged_currency: "SOMETHING",
        pegged_subunit_to_unit: 1000,
        updated_at: DateTime.from_unix!(1_546_423_200)
      }

      assert {:ok, @parsed_fees} == FeeServer.current_fees()

      # corrupt file, refresh, check fees did not change
      assert capture_log(fn ->
               overwrite_fee_file(file_path, file_name, "[not a json]")
               refresh_fees()
             end) =~ ~r/\[error\].*Unable to update fees/

      assert {:ok, @parsed_fees} == FeeServer.current_fees()
      assert server_alive?()

      # fix file, reload, check changes applied
      overwrite_fee_file(file_path, file_name, %{@payment_tx_type => %{@eth_hex => new_fee}})
      refresh_fees()

      assert {:ok, %{@payment_tx_type => %{@eth => new_fee}}} == FeeServer.current_fees()
      assert server_alive?()

      exit_fn.()
    end

    test "starting with corrupted file makes server die", %{fee_file_path: file_path, fee_file_name: file_name} do
      overwrite_fee_file(file_path, file_name, "[not a json]")
      {:died, log} = start_fee_server()

      assert log =~ ~r/\[error\].*Unable to update fees/
      assert false == server_alive?()
    end

    test "previous fees are nil when starting" do
      {:started, _log, exit_fn} = start_fee_server()
      assert nil == :ets.lookup_element(:fees_bucket, :previous_fees, 2)
      assert {:ok, %{1 => %{@eth => [1], @not_eth => [2]}, 2 => %{@eth => [1]}}} == FeeServer.accepted_fees()
      exit_fn.()
    end

    test "previous fees are set when fees are updated", %{fee_file_path: file_path, fee_file_name: file_name} do
      new_fee = %{
        amount: 5,
        subunit_to_unit: 100,
        pegged_amount: 2,
        pegged_currency: "SOMETHING",
        pegged_subunit_to_unit: 1000,
        updated_at: DateTime.from_unix!(1_546_423_200)
      }

      {:started, _log, exit_fn} = start_fee_server()

      assert nil == :ets.lookup_element(:fees_bucket, :previous_fees, 2)
      assert {:ok, %{1 => %{@eth => [1], @not_eth => [2]}, 2 => %{@eth => [1]}}} == FeeServer.accepted_fees()

      overwrite_fee_file(file_path, file_name, %{@payment_tx_type => %{@eth_hex => new_fee}})
      refresh_fees()

      assert @parsed_fees == :ets.lookup_element(:fees_bucket, :previous_fees, 2)
      assert {:ok, %{1 => %{@eth => [5, 1], @not_eth => [2]}, 2 => %{@eth => [1]}}} == FeeServer.accepted_fees()

      exit_fn.()
    end

    test "previous fees expire after the set duration", %{fee_file_path: file_path, fee_file_name: file_name} do
      new_fee = %{
        amount: 5,
        subunit_to_unit: 100,
        pegged_amount: 2,
        pegged_currency: "SOMETHING",
        pegged_subunit_to_unit: 1000,
        updated_at: DateTime.from_unix!(1_546_423_200)
      }

      {:started, _log, exit_fn} = start_fee_server()

      overwrite_fee_file(file_path, file_name, %{@payment_tx_type => %{@eth_hex => new_fee}})
      refresh_fees()

      assert @parsed_fees == :ets.lookup_element(:fees_bucket, :previous_fees, 2)
      assert {:ok, %{1 => %{@eth => [5, 1], @not_eth => [2]}, 2 => %{@eth => [1]}}} == FeeServer.accepted_fees()

      sleep_time = Application.fetch_env!(:omg_child_chain, :fee_buffer_duration_ms)
      Process.sleep(sleep_time)

      assert nil == :ets.lookup_element(:fees_bucket, :previous_fees, 2)
      assert {:ok, %{1 => %{@eth => [5]}}} == FeeServer.accepted_fees()

      exit_fn.()
    end

    test "previous fees are not nil if fees updated during buffer period", %{
      fee_file_path: file_path,
      fee_file_name: file_name
    } do
      # This test is to ensure that the timer is correcly cancelled when new fees
      # come in while in buffer period.
      new_fee_1 = %{
        amount: 5,
        subunit_to_unit: 100,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_unix!(1_546_423_200)
      }

      new_fee_2 = %{
        amount: 2,
        subunit_to_unit: 100,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_unix!(1_546_423_200)
      }

      {:started, _log, exit_fn} = start_fee_server()

      overwrite_fee_file(file_path, file_name, %{@payment_tx_type => %{@eth_hex => new_fee_1}})
      refresh_fees()

      assert @parsed_fees == :ets.lookup_element(:fees_bucket, :previous_fees, 2)
      assert {:ok, %{1 => %{@eth => [5, 1], @not_eth => [2]}, 2 => %{@eth => [1]}}} == FeeServer.accepted_fees()

      half_buffer_duration =
        :omg_child_chain
        |> Application.fetch_env!(:fee_buffer_duration_ms)
        |> div(2)

      Process.sleep(half_buffer_duration)

      overwrite_fee_file(file_path, file_name, %{@payment_tx_type => %{@eth_hex => new_fee_2}})
      refresh_fees()

      Process.sleep(half_buffer_duration)

      assert %{1 => %{@eth => new_fee_1}} == :ets.lookup_element(:fees_bucket, :previous_fees, 2)
      assert {:ok, %{1 => %{@eth => [2, 5]}}} == FeeServer.accepted_fees()

      exit_fn.()
    end
  end

  defp start_fee_server() do
    log = capture_log(fn -> GenServer.start(FeeServer, [], name: TestFeeServer) end)

    case GenServer.whereis(TestFeeServer) do
      pid when is_pid(pid) ->
        # switch of internal timer to don't interfere with tests
        if tref = Map.get(:sys.get_state(TestFeeServer), :tref) do
          {:ok, :cancel} = :timer.cancel(tref)
        end

        if buffer_timer = Map.get(:sys.get_state(TestFeeServer), :expire_fee_timer) do
          _ = Process.cancel_timer(buffer_timer)
        end

        {:started, log, fn -> GenServer.stop(pid) end}

      nil ->
        {:died, log}
    end
  end

  defp refresh_fees() do
    pid = GenServer.whereis(TestFeeServer)

    capture_log(fn ->
      logs = capture_log(fn -> Process.send(pid, :update_fee_specs, []) end)

      case logs do
        "" -> wait_for_log()
        logs -> logs
      end
    end)
  end

  defp wait_for_log() do
    # wait maximal 1s for logs
    Enum.reduce_while(1..100, nil, fn _, _ ->
      logs = capture_log(fn -> Process.sleep(10) end)

      case logs do
        "" -> {:cont, ""}
        logs -> {:halt, logs}
      end
    end)
  end

  defp server_alive?() do
    case GenServer.whereis(TestFeeServer) do
      pid when is_pid(pid) ->
        Process.alive?(pid)

      _ ->
        false
    end
  end

  defp overwrite_fee_file(file_path, file_name, content) do
    # file modification date is in seconds
    Process.sleep(1000)
    {:ok, ^file_path, ^file_name} = TestHelper.write_fee_file(content, file_path, file_name)
  end
end
