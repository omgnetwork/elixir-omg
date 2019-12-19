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

defmodule OMG.WatcherInfo.Factory.TransactionFactory do
  defmacro __using__(_opts) do
    quote do
      def transaction_factory(attrs \\ nil) do
        # a default 'sent_at' DateTime to use if none is passed in via args
        {:ok, default_test_datetime, 0} = DateTime.from_iso8601("2019-12-12T11:11:11Z")

        sent_at = attrs[:sent_at] || default_test_datetime

        transaction = %OMG.WatcherInfo.DB.Transaction{
          txhash: sequence(:transaction_hash, fn seq -> <<seq::256>> end),
          txindex: sequence(:transaction_txindex, fn seq -> seq end),
          txbytes: sequence(:transaction_txbytes, fn seq -> <<seq::256>> end),
          sent_at: sequence(:transaction_sent_at, fn seq -> DateTime.add(sent_at, seq) end),
          metadata: sequence(:transaction_metadata, fn seq -> <<seq::256>> end),
          block: attrs[:block] || build(:block)
        }

        merge_attributes(transaction, attrs)
      end
    end
  end
end
