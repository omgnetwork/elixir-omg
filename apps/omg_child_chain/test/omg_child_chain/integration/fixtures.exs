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

defmodule OMG.ChildChain.Integration.Fixtures do
  use ExUnitFixtures.FixtureModule
  use OMG.Fixtures
  use OMG.Eth.Fixtures
  use OMG.DB.Fixtures

  alias OMG.ChildChainRPC.Web.TestHelper
  alias OMG.Eth
  alias OMG.Status.Alert.Alarm
  alias OMG.TestHelper
  alias Support.DevHelper
  alias Support.Integration.DepositHelper

  @payment_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v1)

  deffixture fee_file(token) do
    # ensuring that the child chain handles the token (esp. fee-wise)

    enc_eth = Eth.Encoding.to_hex(OMG.Eth.RootChain.eth_pseudo_address())

    {:ok, path, file_name} =
      TestHelper.write_fee_file(%{
        @payment_tx_type => %{
          enc_eth => %{
            amount: 2,
            pegged_amount: 1,
            subunit_to_unit: 1_000_000_000_000_000_000,
            pegged_currency: "USD",
            pegged_subunit_to_unit: 100,
            updated_at: DateTime.utc_now()
          },
          Eth.Encoding.to_hex(token) => %{
            amount: 0,
            pegged_amount: 1,
            subunit_to_unit: 1_000_000_000_000_000_000,
            pegged_currency: "USD",
            pegged_subunit_to_unit: 100,
            updated_at: DateTime.utc_now()
          }
        }
      })

    default_file = Application.fetch_env!(:omg_child_chain, :fee_specs_file_name)
    Application.put_env(:omg_child_chain, :fee_specs_file_name, file_name, persistent: true)

    on_exit(fn ->
      :ok = File.rm(path)
      Application.put_env(:omg_child_chain, :fee_specs_file_name, default_file)
    end)

    file_name
  end

  deffixture in_beam_child_chain(root_chain_contract_config, fee_file, db_initialized) do
    # match variables to hide "unused var" warnings (can't be fixed by underscoring in line above, breaks macro):
    _ = root_chain_contract_config
    _ = db_initialized
    _ = fee_file
    # need to override that to very often, so that many checks fall in between a single child chain block submission
    {:ok, started_apps} = Application.ensure_all_started(:omg_child_chain)
    {:ok, started_apps_rpc} = Application.ensure_all_started(:omg_child_chain_rpc)

    on_exit(fn ->
      (started_apps ++ started_apps_rpc)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    wait_for_web()
  end

  deffixture alice_deposits(alice, token) do
    prepare_deposits(alice, token)
  end

  deffixture stable_alice_deposits(stable_alice, token) do
    prepare_deposits(stable_alice, token)
  end

  defp prepare_deposits(alice, token_addr) do
    some_value = 10

    {:ok, _} = DevHelper.import_unlock_fund(alice)

    deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, some_value)
    {:ok, _} = Eth.Token.mint(alice.addr, some_value, token_addr) |> DevHelper.transact_sync!()
    token_deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, some_value, token_addr)

    {deposit_blknum, token_deposit_blknum}
  end

  defp wait_for_web(), do: wait_for_web(100)

  defp wait_for_web(counter) do
    case Keyword.has_key?(Alarm.all(), elem(Alarm.main_supervisor_halted(__MODULE__), 0)) do
      true ->
        Process.sleep(100)
        wait_for_web(counter - 1)

      false ->
        :ok
    end
  end
end
