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
      def txoutput_factory(attrs \\ nil) do
        txoutput = %OMG.WatcherInfo.DB.TxOutput{
          blknum: sequence(:txoutput_blknum, fn seq -> seq end),
          txindex: sequence(:txoutput_txindex, fn seq -> seq end),
          oindex: sequence(:txoutput_oindex, fn seq -> seq end),
          creating_transaction: nil,
          spending_transaction: nil,
          spending_tx_oindex: nil,
          owner: sequence(:txoutput_owner, fn seq -> <<seq::160>> end),
          amount: 1,
          currency: sequence(:txoutput_currency, fn seq -> <<seq::160>> end),
          proof: sequence(:txoutput_proof, fn seq -> <<seq::256>> end),
          child_chain_utxohash: nil
        }

        merge_attributes(txoutput, attrs)
      end
    end
  end
end
