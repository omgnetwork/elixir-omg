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
  def start_exit() do
    %ABI.FunctionSelector{
      function: "startExit",
      input_names: [
        "utxoPosToExit",
        "rlpOutputTxToContract",
        "outputTxToContractInclusionProof",
        "rlpInputCreationTx",
        "inputCreationTxInclusionProof",
        "utxoPosInput"
      ],
      inputs_indexed: nil,
      method_id: <<191, 31, 49, 109>>,
      returns: [],
      type: :function,
      types: [{:uint, 256}, :bytes, :bytes, :bytes, :bytes, {:uint, 256}]
    }
  end

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

  # min_exit_period/0, get_version/0, exit_games/0, vaults/0 are
  # victims of unfortinate bug: https://github.com/poanetwork/ex_abi/issues/25
  # All these selectors were intially pulled in with
  # `ABI.parse_specification(contract_abi_json_decoded,include_events?: true)`
  # and later modified so that `types` hold what `returns` should have because of
  # issue 25.
  # the commented properties of the struct is what it was generated,
  # the new types were added to mitigate the bug.
  def min_exit_period() do
    %ABI.FunctionSelector{
      function: "minExitPeriod",
      input_names: ["min_exit_period"],
      inputs_indexed: nil,
      method_id: <<212, 162, 180, 239>>,
      # returns: [uint: 256],
      type: :function,
      # types: []
      types: [uint: 256]
    }
  end

  def get_version() do
    %ABI.FunctionSelector{
      function: "getVersion",
      input_names: ["version"],
      inputs_indexed: nil,
      method_id: <<13, 142, 110, 44>>,
      # returns: [:string],
      type: :function,
      # types: []
      types: [:string]
    }
  end

  def exit_games() do
    %ABI.FunctionSelector{
      function: "exitGames",
      input_names: ["exit_game_address"],
      inputs_indexed: nil,
      method_id: <<175, 7, 151, 100>>,
      # returns: [:address],
      type: :function,
      # types: [uint: 256]
      types: [:address]
    }
  end

  def vaults() do
    %ABI.FunctionSelector{
      function: "vaults",
      input_names: ["vault_address"],
      inputs_indexed: nil,
      method_id: <<140, 100, 234, 74>>,
      # returns: [:address],
      type: :function,
      # types: [uint: 256]
      types: [:address]
    }
  end

  def child_block_interval() do
    %ABI.FunctionSelector{
      function: "childBlockInterval",
      input_names: ["child_block_interval"],
      inputs_indexed: nil,
      method_id: <<56, 169, 224, 188>>,
      # returns: [uint: 256],
      type: :function,
      # types: []
      types: [uint: 256]
    }
  end

  def next_child_block() do
    %ABI.FunctionSelector{
      function: "nextChildBlock",
      input_names: ["block_number"],
      inputs_indexed: nil,
      method_id: <<76, 168, 113, 79>>,
      # returns: [uint: 256],
      type: :function,
      # types: []
      types: [uint: 256]
    }
  end

  def blocks() do
    %ABI.FunctionSelector{
      function: "blocks",
      input_names: ["block_hash", "block_timestamp"],
      inputs_indexed: nil,
      method_id: <<242, 91, 63, 153>>,
      # returns: [bytes: 32, uint: 256],
      type: :function,
      # types: [uint: 256]
      types: [bytes: 32, uint: 256]
    }
  end

  def standard_exits() do
    %ABI.FunctionSelector{
      function: "standardExits",
      input_names: ["standard_exit_structs"],
      inputs_indexed: nil,
      method_id: <<12, 165, 182, 118>>,
      # returns: [
      #   array: {:tuple, [:bool, {:uint, 256}, {:bytes, 32}, :address, {:uint, 256}, {:uint, 256}]}
      # ],
      type: :function,
      # types: [array: {:uint, 160}]
      types: [
        array: {:tuple, [:bool, {:uint, 256}, {:bytes, 32}, :address, {:uint, 256}, {:uint, 256}]}
      ]
    }
  end

  def in_flight_exits() do
    %ABI.FunctionSelector{
      function: "inFlightExits",
      input_names: ["in_flight_exit_structs"],
      inputs_indexed: nil,
      method_id: <<206, 201, 225, 167>>,
      # returns: [
      #   array: {:tuple,
      #           [
      #             :bool,
      #             {:uint, 64},
      #             {:uint, 256},
      #             {:uint, 256},
      #             {:array, :tuple, 4},
      #             {:array, :tuple, 4},
      #             :address,
      #             {:uint, 256},
      #             {:uint, 256}
      #           ]}
      # ],
      type: :function,
      # types: [array: {:uint, 160}]
      types: [
        {:array, {:tuple, [:bool, {:uint, 64}, {:uint, 256}, {:uint, 256}, :address, {:uint, 256}, {:uint, 256}]}}
      ]
    }
  end
end
