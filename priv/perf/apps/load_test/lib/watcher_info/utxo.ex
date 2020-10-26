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
# limitations under the License.w

defmodule LoadTest.WatcherInfo.Utxo do
  require Logger

  alias LoadTest.Connection.WatcherInfo
  alias LoadTest.Utils.Encoding
  alias LoadTest.Service.Sync

  @poll_timeout 60_000

  def get_utxos(sender) do
    {:ok, response} =
      Sync.repeat_until_success(
        fn ->
          WatcherInfoAPI.Api.Account.account_get_utxos(
            WatcherInfo.client(),
            %WatcherInfoAPI.Model.AddressBodySchema1{
              address: Encoding.to_hex(sender.addr)
            }
          )
        end,
        @poll_timeout,
        "Failes to fetch utxos"
      )

    {:ok, Jason.decode!(response.body)}
  end
end
