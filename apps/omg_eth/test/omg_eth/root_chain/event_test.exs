# Copyright 2019-2020 OMG Network Pte Ltd
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
defmodule OMG.RootChain.EventTest do
  use ExUnit.Case, async: true
  alias OMG.Eth.RootChain.Event

  test "that filter and building an event definition works as expected" do
    assert Event.get_events([:deposit_created]) == ["DepositCreated(address,uint256,address,uint256)"]
  end

  test "that order of returned events is preserved" do
    assert Event.get_events([:deposit_created, :in_flight_exit_challenged, :in_flight_exit_started]) == [
             "DepositCreated(address,uint256,address,uint256)",
             "InFlightExitChallenged(address,bytes32,uint256,uint16,bytes,uint16,bytes)",
             "InFlightExitStarted(address,bytes32,bytes,uint256[],bytes[])"
           ]
  end
end
