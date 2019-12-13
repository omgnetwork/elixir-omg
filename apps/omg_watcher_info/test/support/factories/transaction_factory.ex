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
      def transaction_factory do
        %OMG.WatcherInfo.DB.Transaction{
          txhash: <<1::256>>,
          txindex: 1,
          txbytes: <<0::256>>,
          sent_at: DateTime.from_iso8601("2019-12-12T01:01:01Z"),
          metadata: <<0::256>>
        }
      end
    end
  end
end

# has_many(:inputs, DB.TxOutput, foreign_key: :spending_txhash)
# has_many(:outputs, DB.TxOutput, foreign_key: :creating_txhash)
# belongs_to(:block, DB.Block, foreign_key: :blknum, references: :blknum, type: :integer)
