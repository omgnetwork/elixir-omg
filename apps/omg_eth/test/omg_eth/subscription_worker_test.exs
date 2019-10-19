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

defmodule OMG.Eth.SubscriptionWorkerTest do
  @moduledoc false
  alias OMG.Eth.SubscriptionWorker

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  use OMG.Utils.LoggerExt

  @moduletag :common

  setup do
    _ = Application.ensure_all_started(:omg_bus)
    vcr_path = Path.join(__DIR__, "../fixtures/vcr_cassettes")
    ExVCR.Config.cassette_library_dir(vcr_path)
    :ok
  end

  test "that worker can subscribe to different events and receive events" do
    use_cassette "ganache/subscription_worker" do
      listen_to = ["newHeads", "newPendingTransactions"]

      Enum.each(
        listen_to,
        fn listen ->
          params = [listen_to: listen, ws_url: Application.get_env(:omg_eth, :ws_url)]
          _ = SubscriptionWorker.start_link([{:event_bus, OMG.Bus} | params])
          :ok = OMG.Bus.subscribe(listen, link: true)
          event = String.to_atom(listen)

          receive do
            {:internal_event_bus, ^event, _message} ->
              assert true
          end
        end
      )
    end
  end
end
