# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.Integration.Fixtures do
  use ExUnitFixtures.FixtureModule
  use OMG.Eth.Fixtures
  use OMG.DB.Fixtures

  alias OMG.Eth

  import OMG.API.Integration.DepositHelper

  deffixture fee_file(token) do
    # ensuring that the child chain handles the token (esp. fee-wise)

    enc_eth = Eth.Encoding.to_hex(OMG.API.Crypto.zero_address())
    {:ok, path} = OMG.API.TestHelper.write_fee_file(%{enc_eth => 0, Eth.Encoding.to_hex(token) => 0})
    default_path = Application.get_env(:omg_api, :fee_specs_file_path)
    Application.put_env(:omg_api, :fee_specs_file_path, path, persistent: true)

    on_exit(fn ->
      Application.put_env(:omg_api, :fee_specs_file_path, default_path)
    end)

    path
  end

  deffixture omg_child_chain(root_chain_contract_config, fee_file, db_initialized) do
    # match variables to hide "unused var" warnings (can't be fixed by underscoring in line above, breaks macro):
    _ = root_chain_contract_config
    _ = db_initialized
    _ = fee_file
    Application.put_env(:omg_api, :ethereum_event_block_finality_margin, 2, persistent: true)
    # need to overide that to very often, so that many checks fall in between a single child chain block submission
    {:ok, started_apps} = Application.ensure_all_started(:omg_api)

    on_exit(fn ->
      started_apps
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end

  deffixture alice_deposits(alice, token) do
    deposit(alice, token)
  end

  deffixture stable_alice_deposits(stable_alice, token) do
    deposit(stable_alice, token)
  end

  defp deposit(alice, token) do
    {:ok, _} = Eth.DevHelpers.import_unlock_fund(alice)

    deposit_blknum = deposit_to_child_chain(alice.addr, 10)
    token_deposit_blknum = deposit_to_child_chain(alice.addr, 10, token)

    {deposit_blknum, token_deposit_blknum}
  end
end
