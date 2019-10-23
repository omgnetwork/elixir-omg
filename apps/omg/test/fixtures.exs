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

defmodule OMG.Fixtures do
  use ExUnitFixtures.FixtureModule

  alias OMG.State.Core

  import OMG.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  deffixture(entities, do: entities())

  deffixture(alice(entities), do: entities.alice)
  deffixture(bob(entities), do: entities.bob)
  deffixture(carol(entities), do: entities.carol)

  deffixture(stable_alice(entities), do: entities.stable_alice)
  deffixture(stable_bob(entities), do: entities.stable_bob)
  deffixture(stable_mallory(entities), do: entities.stable_mallory)

  deffixture state_empty() do
    {:ok, child_block_interval} = OMG.Eth.RootChain.get_child_block_interval()
    {:ok, state} = Core.extract_initial_state(0, child_block_interval)
    state
  end

  deffixture state_alice_deposit(state_empty, alice) do
    do_deposit(state_empty, alice, %{amount: 10, currency: @eth, blknum: 1})
  end

  deffixture state_stable_alice_deposit(state_empty, stable_alice) do
    do_deposit(state_empty, stable_alice, %{amount: 10, currency: @eth, blknum: 1})
  end
end
