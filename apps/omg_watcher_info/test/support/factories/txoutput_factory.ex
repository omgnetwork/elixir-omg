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

defmodule OMG.WatcherInfo.Factory.TxOutputFactory do
  defmacro __using__(_opts) do
    quote do
      def txoutput_factory do
        %OMG.WatcherInfo.DB.TxOutput{
          blknum: 1,
          txindex: 0,
          oindex: 0,
          amount: 1,
          currency: <<0::160>>,
          proof: <<0::256>>
        }
      end
    end
  end
end

# field(:blknum, :integer, primary_key: true)
# field(:txindex, :integer, primary_key: true)
# field(:oindex, :integer, primary_key: true)
# field(:owner, :binary)
# field(:amount, OMG.WatcherInfo.DB.Types.IntegerType)
# field(:currency, :binary)
# field(:proof, :binary)
# field(:spending_tx_oindex, :integer)
# field(:child_chain_utxohash, :binary)

# belongs_to(:creating_transaction, DB.Transaction, foreign_key: :creating_txhash, references: :txhash, type: :binary)
# belongs_to(:spending_transaction, DB.Transaction, foreign_key: :spending_txhash, references: :txhash, type: :binary)

# many_to_many(
#   :ethevents,
#   DB.EthEvent,
#   join_through: "ethevents_txoutputs",
#   join_keys: [child_chain_utxohash: :child_chain_utxohash, root_chain_txhash_event: :root_chain_txhash_event]
# )

# timestamps(type: :utc_datetime)
