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

defmodule OMG.WatcherInformational.Integration.TestServerTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.WatcherInformational.HttpRPC.Client
  alias OMG.WatcherInformational.Integration.TestServer

  @expected_block_hash <<0::256>>

  describe "/block.get -" do
    @response TestServer.make_response(%{
                blknum: 123_000,
                hash: Encoding.to_hex(@expected_block_hash),
                transactions: []
              })

    @tag fixtures: [:test_server]
    test "successful response is parsed to expected map", %{test_server: context} do
      TestServer.with_route(context, "/block.get", @response)

      assert {:ok,
              %{
                transactions: [],
                number: 123_000,
                hash: @expected_block_hash
              }} == Client.get_block(@expected_block_hash, context.fake_addr)
    end
  end
end
