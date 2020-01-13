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

defmodule OMG.WatcherInfo.Factory.EthEvent do
  defmacro __using__(_opts) do
    quote do
      alias OMG.WatcherInfo.DB

      @doc """
      EthEvent factory.

      Generates an ethevent. For testing flexibility, an ethevent can be created with 0 txoutputs. Although this does not
      conform to the business logic, this violates no database constraints.

      To associate an ethevent with one or more txoutputs, an array of txoutputs can be passed in via by overriding
      `txoutputs`.

      Most scenarios will have a only a 1-1 relationship between ethevents an txoutputs or a one-to-many
      (txoutput -> ethevents) relationship. However, with an ExitFinalized ethevent (processExits()) scenario, an ethevent
      may have many txoutputs. A txoutput for every utxo in the exit queue when processExits() was called.

      The default event type is `:deposit`, but can be overridden by setting `event_type`.
      """
      def ethevent_factory(attrs \\ %{}) do
        ethevent = %DB.EthEvent{
          root_chain_txhash: insecure_random_bytes(32),
          # within a log there may be 0 or more ethereum events, this is the index of the
          # event within the log
          log_index: 0,
          event_type: :deposit,
          txoutputs: []
        }

        ethevent = merge_attributes(ethevent, attrs)

        root_chain_txhash_event =
          DB.EthEvent.generate_root_chain_txhash_event(ethevent.root_chain_txhash, ethevent.log_index)

        Map.put(ethevent, :root_chain_txhash_event, root_chain_txhash_event)
      end
    end
  end
end
