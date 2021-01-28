# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Eth.RootChain.AbiEventSelector do
  @moduledoc """
  We define Solidity Event selectors that help us decode returned values from function calls.
  Function names are to be used as inputs to Event Fetcher.
  Function names describe the type of the event Event Fetcher will retrieve.
  """

  @spec exit_started() :: ABI.FunctionSelector.t()
  def exit_started() do
    %ABI.FunctionSelector{
      function: "ExitStarted",
      input_names: ["owner", "exit_id", "utxo_pos", "output_tx"],
      inputs_indexed: [true, false, false, false],
      method_id: <<190, 31, 206, 232>>,
      returns: [],
      type: :event,
      types: [:address, {:uint, 168}, {:uint, 256}, :bytes]
    }
  end

  @spec in_flight_exit_started() :: ABI.FunctionSelector.t()
  def in_flight_exit_started() do
    %ABI.FunctionSelector{
      function: "InFlightExitStarted",
      input_names: ["initiator", "txHash", "inFlightTx", "inputUtxosPos", "inFlightTxWitnesses", "inputTxs"],
      inputs_indexed: [true, true, false, false, false, false],
      method_id: <<150, 80, 84, 111>>,
      returns: [],
      type: :event,
      types: [
        :address,
        {:bytes, 32},
        :bytes,
        {:array, {:uint, 256}},
        {:array, :bytes},
        {:array, :bytes}
      ]
    }
  end

  @spec in_flight_exit_deleted() :: ABI.FunctionSelector.t()
  def in_flight_exit_deleted() do
    %ABI.FunctionSelector{
      function: "InFlightExitDeleted",
      input_names: ["exitId"],
      inputs_indexed: [true],
      method_id: <<25, 145, 196, 195>>,
      returns: [],
      type: :event,
      types: [uint: 168]
    }
  end

  @spec in_flight_exit_challenged() :: ABI.FunctionSelector.t()
  def in_flight_exit_challenged() do
    %ABI.FunctionSelector{
      function: "InFlightExitChallenged",
      input_names: [
        "challenger",
        "txHash",
        "challengeTxPosition",
        "inFlightTxInputIndex",
        "challengeTx",
        "challengeTxInputIndex",
        "challengeTxWitness"
      ],
      inputs_indexed: [true, true, false, false, false, false, false],
      method_id: <<141, 128, 235, 79>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 256}, {:uint, 16}, :bytes, {:uint, 16}, :bytes]
    }
  end

  @spec deposit_created() :: ABI.FunctionSelector.t()
  def deposit_created() do
    %ABI.FunctionSelector{
      function: "DepositCreated",
      input_names: ["depositor", "blknum", "token", "amount"],
      inputs_indexed: [true, true, true, false],
      method_id: <<24, 86, 145, 34>>,
      returns: [],
      type: :event,
      types: [:address, {:uint, 256}, :address, {:uint, 256}]
    }
  end

  @spec in_flight_exit_input_piggybacked() :: ABI.FunctionSelector.t()
  def in_flight_exit_input_piggybacked() do
    %ABI.FunctionSelector{
      function: "InFlightExitInputPiggybacked",
      input_names: ["exitTarget", "txHash", "inputIndex"],
      inputs_indexed: [true, true, false],
      method_id: <<169, 60, 14, 155>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 16}]
    }
  end

  @spec in_flight_exit_output_piggybacked() :: ABI.FunctionSelector.t()
  def in_flight_exit_output_piggybacked() do
    %ABI.FunctionSelector{
      function: "InFlightExitOutputPiggybacked",
      input_names: ["exitTarget", "txHash", "outputIndex"],
      inputs_indexed: [true, true, false],
      method_id: <<110, 205, 142, 121>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 16}]
    }
  end

  @spec block_submitted() :: ABI.FunctionSelector.t()
  def block_submitted() do
    %ABI.FunctionSelector{
      function: "BlockSubmitted",
      input_names: ["blockNumber"],
      inputs_indexed: [false],
      method_id: <<90, 151, 143, 71>>,
      returns: [],
      type: :event,
      types: [uint: 256]
    }
  end

  @spec exit_finalized() :: ABI.FunctionSelector.t()
  def exit_finalized() do
    %ABI.FunctionSelector{
      function: "ExitFinalized",
      input_names: ["exitId"],
      inputs_indexed: [true],
      method_id: <<112, 229, 37, 2>>,
      returns: [],
      type: :event,
      types: [uint: 168]
    }
  end

  @spec in_flight_exit_challenge_responded() :: ABI.FunctionSelector.t()
  def in_flight_exit_challenge_responded() do
    # <<99, 124, 196, 167>> == "c|ħ"
    %ABI.FunctionSelector{
      function: "InFlightExitChallengeResponded",
      input_names: ["challenger", "txHash", "challengeTxPosition"],
      inputs_indexed: [true, true, false],
      # method_id: "c|ħ",
      method_id: <<99, 124, 196, 167>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 256}]
    }
  end

  @spec exit_challenged() :: ABI.FunctionSelector.t()
  def exit_challenged() do
    %ABI.FunctionSelector{
      function: "ExitChallenged",
      input_names: ["utxoPos"],
      inputs_indexed: [true],
      method_id: <<93, 251, 165, 38>>,
      returns: [],
      type: :event,
      types: [uint: 256]
    }
  end

  @spec in_flight_exit_input_blocked() :: ABI.FunctionSelector.t()
  def in_flight_exit_input_blocked() do
    %ABI.FunctionSelector{
      function: "InFlightExitInputBlocked",
      input_names: ["challenger", "txHash", "inputIndex"],
      inputs_indexed: [true, true, false],
      method_id: <<71, 148, 4, 88>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 16}]
    }
  end

  @spec in_flight_exit_output_blocked() :: ABI.FunctionSelector.t()
  def in_flight_exit_output_blocked() do
    %ABI.FunctionSelector{
      function: "InFlightExitOutputBlocked",
      input_names: ["challenger", "txHash", "outputIndex"],
      inputs_indexed: [true, true, false],
      method_id: <<203, 232, 218, 210>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 16}]
    }
  end

  @spec in_flight_exit_input_withdrawn() :: ABI.FunctionSelector.t()
  def in_flight_exit_input_withdrawn() do
    %ABI.FunctionSelector{
      function: "InFlightExitInputWithdrawn",
      input_names: ["exitId", "inputIndex"],
      inputs_indexed: [true, false],
      method_id: <<32, 14, 10, 68>>,
      returns: [],
      type: :event,
      types: [uint: 168, uint: 16]
    }
  end

  @spec in_flight_exit_output_withdrawn() :: ABI.FunctionSelector.t()
  def in_flight_exit_output_withdrawn() do
    %ABI.FunctionSelector{
      function: "InFlightExitOutputWithdrawn",
      input_names: ["exitId", "outputIndex"],
      inputs_indexed: [true, false],
      method_id: <<61, 204, 34, 81>>,
      returns: [],
      type: :event,
      types: [uint: 168, uint: 16]
    }
  end
end
