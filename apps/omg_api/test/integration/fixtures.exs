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

  deffixture omg_child_chain(root_chain_contract_config, token_contract_config, db_initialized) do
    # match variables to hide "unused var" warnings (can't be fixed by underscoring in line above, breaks macro):
    _ = root_chain_contract_config
    _ = db_initialized
    _ = token_contract_config
    Application.put_env(:omg_api, :ethereum_event_block_finality_margin, 2, persistent: true)
    # need to overide that to very often, so that many checks fall in between a single child chain block submission
    {:ok, started_apps} = Application.ensure_all_started(:omg_api)
    {:ok, started_jsonrpc} = Application.ensure_all_started(:omg_jsonrpc)

    on_exit(fn ->
      (started_apps ++ started_jsonrpc)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end

  deffixture alice_deposits(alice, token) do
    {:ok, alice_address} = Eth.DevHelpers.import_unlock_fund(alice)
    deposit_blknum = deposit_to_child_chain(alice_address, 10)
    token_deposit_blknum = deposit_to_child_chain(alice_address, 10, token)

    {deposit_blknum, token_deposit_blknum}
  end
end
