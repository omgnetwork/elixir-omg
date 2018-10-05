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

defmodule OMG.Watcher.Integration.InvalidExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use OMG.API.Integration.Fixtures
  use Plug.Test
  use Phoenix.ChannelTest

  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias OMG.API.Crypto
  alias OMG.Eth
  alias OMG.API
  alias OMG.JSONRPC.Client
  alias OMG.Watcher.Eventer.Event
  alias OMG.Watcher.Web.Channel

  import ExUnit.CaptureLog

  @moduletag :integration

  @timeout 80_000
  @eth OMG.API.Crypto.zero_address()

  @endpoint OMG.Watcher.Web.Endpoint

  #  TODO complete this test
  @tag fixtures: [:watcher_sandbox, :child_chain, :alice, :alice_deposits]
  @tag :skip
  test "transaction which is using already spent utxo from exit and happened before end of m_sv causes to emit invalid_exit event ",
       %{alice: alice, alice_deposits: {deposit_blknum, _}} do
  end
end
