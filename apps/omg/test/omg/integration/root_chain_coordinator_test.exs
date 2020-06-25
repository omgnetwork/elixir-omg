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

defmodule OMG.RootChainCoordinatorTest do
  @moduledoc """
  Smoke tests the imperative shells of `OMG.EthereumEventListener` and `OMG.RootChainCoordinator` working together
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use OMG.DB.Fixtures
  use OMG.Eth.Fixtures

  @moduletag :integration
  @moduletag :common
  setup do
    {:ok, bus_apps} = Application.ensure_all_started(:omg_bus)
    db_path = Briefly.create!(directory: true)
    :ok = OMG.DB.init(db_path)
    {:ok, eth_apps} = Application.ensure_all_started(:omg_eth)
    {:ok, status_apps} = Application.ensure_all_started(:omg_status)
    apps = bus_apps ++ eth_apps ++ status_apps

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)

    :ok
  end
end
