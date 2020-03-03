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

defmodule OMG.Eth.RootChain.AbiFunctionSelector do
  @moduledoc """

  We define Solidity Function selectors that help us decode returned values from function calls
  """
  def start_standard_exit() do
    %ABI.FunctionSelector{
      function: "startStandardExit",
      input_names: ["utxoPos", "rlpOutputTx", "outputTxInclusionProof"],
      inputs_indexed: nil,
      method_id: <<112, 224, 20, 98>>,
      returns: [],
      type: :function,
      types: [tuple: [{:uint, 256}, :bytes, :bytes]]
    }
  end

  def challenge_in_flight_exit_not_canonical() do
    %ABI.FunctionSelector{
      function: "challengeInFlightExitNotCanonical",
      input_names: [
        "inputTx",
        "inputUtxoPos",
        "inFlightTx",
        "inFlightTxInputIndex",
        "competingTx",
        "competingTxInputIndex",
        "competingTxPos",
        "competingTxInclusionProof",
        "competingTxWitness"
      ],
      inputs_indexed: [true, true, true, true, true, true, true, true, true],
      method_id: <<232, 54, 34, 152>>,
      returns: [],
      type: :function,
      types: [
        tuple: [
          :bytes,
          {:uint, 256},
          :bytes,
          {:uint, 16},
          :bytes,
          {:uint, 16},
          {:uint, 256},
          :bytes,
          :bytes
        ]
      ]
    }
  end

  def start_in_flight_exit() do
    %ABI.FunctionSelector{
      function: "startInFlightExit",
      input_names: ["inFlightTx", "inputTxs", "inputUtxosPos", "inputTxsInclusionProofs", "inFlightTxWitnesses"],
      inputs_indexed: nil,
      method_id: <<90, 82, 133, 20>>,
      returns: [],
      type: :function,
      types: [
        tuple: [
          :bytes,
          {:array, :bytes},
          {:array, {:uint, 256}},
          {:array, :bytes},
          {:array, :bytes}
        ]
      ]
    }
  end
end
