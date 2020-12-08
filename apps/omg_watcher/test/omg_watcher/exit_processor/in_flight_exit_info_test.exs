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
# limitations under the License.

defmodule OMG.Watcher.ExitProcessor.InFlightExitInfoTest do
  @moduledoc false

  use OMG.Watcher.ExitProcessor.Case, async: true

  alias OMG.State.Transaction
  alias OMG.Utxo.Position
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo

  @eth OMG.Eth.zero_address()

  describe "get_input_utxos/1" do
    test "returns a list of input utxos" do
      inputs1 = [
        Position.encode({:utxo_position, 1, 0, 0}),
        Position.encode({:utxo_position, 1, 0, 1})
      ]

      inputs2 = [Position.encode({:utxo_position, 1, 0, 2})]

      ife_infos = [
        ife_info_with_inputs(inputs1),
        ife_info_with_inputs(inputs2)
      ]

      expected = inputs1 ++ inputs2

      assert InFlightExitInfo.get_input_utxos(ife_infos) == expected
    end
  end

  defp ife_info_with_inputs(inputs) do
    tx =
      Transaction.Payment.new(
        [{1, 0, 0}],
        [{"alice", @eth, 1}, {"alice", @eth, 2}],
        <<0::256>>
      )

    %InFlightExitInfo{
      tx: %Transaction.Signed{raw_tx: tx, sigs: <<1::520>>},
      timestamp: 1,
      contract_id: <<1::160>>,
      eth_height: 1,
      is_active: true,
      input_utxos_pos: inputs
    }
  end
end
