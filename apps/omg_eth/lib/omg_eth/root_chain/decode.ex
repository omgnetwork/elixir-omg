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
defmodule OMG.Eth.RootChain.Decode do
  @moduledoc """
  Functions that provide ethereum log decoding 
  """
  alias OMG.Eth.Encoding
  alias OMG.Eth.HackNaming

  def deposit(log) do
    function_spec = deposit_created()

    {^function_spec, data} =
      ABI.Event.find_and_decode(
        [function_spec],
        Encoding.from_hex(Enum.at(log["topics"], 0)),
        Encoding.from_hex(Enum.at(log["topics"], 1)),
        Encoding.from_hex(Enum.at(log["topics"], 2)),
        Encoding.from_hex(Enum.at(log["topics"], 3)),
        Encoding.from_hex(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> HackNaming.deposit()
    |> common_parse_event(log)
  end

  def block_submitted(log) do
    function_spec = block_submitted()

    {^function_spec, data} =
      ABI.Event.find_and_decode(
        [function_spec],
        Encoding.from_hex(Enum.at(log["topics"], 0)),
        nil,
        nil,
        nil,
        Encoding.from_hex(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> HackNaming.block_submitted()
    |> common_parse_event(log)
  end

  def piggybacked(log) do
    function_spec = [
      in_flight_exit_input_piggybacked(),
      in_flight_exit_output_piggybacked()
    ]

    {_function_spec, data} =
      ABI.Event.find_and_decode(
        function_spec,
        Encoding.from_hex(Enum.at(log["topics"], 0)),
        Encoding.from_hex(Enum.at(log["topics"], 1)),
        Encoding.from_hex(Enum.at(log["topics"], 2)),
        nil,
        Encoding.from_hex(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> HackNaming.piggybacked()
    |> common_parse_event(log)
  end

  def exit_finalized(log) do
    function_spec = exit_finalized()

    {_function_spec, data} =
      ABI.Event.find_and_decode(
        [function_spec],
        Encoding.from_hex(Enum.at(log["topics"], 0)),
        Encoding.from_hex(Enum.at(log["topics"], 1)),
        nil,
        nil,
        Encoding.from_hex(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> HackNaming.exit_finalized()
    |> common_parse_event(log)
  end

  def exit_started(log) do
    function_spec = exit_started()

    {_function_spec, data} =
      ABI.Event.find_and_decode(
        [function_spec],
        Encoding.from_hex(Enum.at(log["topics"], 0)),
        Encoding.from_hex(Enum.at(log["topics"], 1)),
        nil,
        nil,
        Encoding.from_hex(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> HackNaming.exit_started()
    |> common_parse_event(log)
  end

  def in_flight_exit_challenged(log) do
    function_spec = in_flight_exit_challenged()

    {_function_spec, data} =
      ABI.Event.find_and_decode(
        [function_spec],
        Encoding.from_hex(Enum.at(log["topics"], 0)),
        Encoding.from_hex(Enum.at(log["topics"], 1)),
        Encoding.from_hex(Enum.at(log["topics"], 2)),
        nil,
        Encoding.from_hex(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> HackNaming.in_flight_exit_challenged()
    |> common_parse_event(log)
  end

  def exit_challenged(log) do
    function_spec = exit_challenged()

    {_function_spec, data} =
      ABI.Event.find_and_decode(
        [function_spec],
        Encoding.from_hex(Enum.at(log["topics"], 0)),
        Encoding.from_hex(Enum.at(log["topics"], 1)),
        nil,
        nil,
        Encoding.from_hex(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> HackNaming.exit_challenged()
    |> common_parse_event(log)
  end

  def in_flight_exit_challenge_responded(log) do
    function_spec = in_flight_exit_challenge_responded()

    {_function_spec, data} =
      ABI.Event.find_and_decode(
        [function_spec],
        Encoding.from_hex(Enum.at(log["topics"], 0)),
        Encoding.from_hex(Enum.at(log["topics"], 1)),
        Encoding.from_hex(Enum.at(log["topics"], 2)),
        nil,
        Encoding.from_hex(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> HackNaming.in_flight_exit_challenge_responded()
    |> common_parse_event(log)
  end

  def challenge_in_flight_exit_not_canonical(log) do
    function_spec = challenge_in_flight_exit_not_canonical()

    data =
      function_spec
      |> ABI.decode(log)
      |> hd()
      |> Tuple.to_list()

    function_spec.input_names
    |> Enum.zip(data)
    |> Enum.into(%{})
    |> HackNaming.challenge_in_flight_exit_not_canonical()
  end

  def in_flight_exit_blocked(log) do
    function_spec = [in_flight_exit_input_blocked(), in_flight_exit_output_blocked()]

    {_function_spec, data} =
      ABI.Event.find_and_decode(
        function_spec,
        Encoding.from_hex(Enum.at(log["topics"], 0)),
        Encoding.from_hex(Enum.at(log["topics"], 1)),
        Encoding.from_hex(Enum.at(log["topics"], 2)),
        nil,
        Encoding.from_hex(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> HackNaming.in_flight_exit_blocked()
    |> common_parse_event(log)
  end

  def in_flight_exit_finalized(log) do
    function_spec = [in_flight_exit_input_withdrawn(), in_flight_exit_output_withdrawn()]

    {_function_spec, data} =
      ABI.Event.find_and_decode(
        function_spec,
        OMG.Eth.Encoding.from_hex(Enum.at(log["topics"], 0)),
        OMG.Eth.Encoding.from_hex(Enum.at(log["topics"], 1)),
        nil,
        nil,
        OMG.Eth.Encoding.from_hex(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> HackNaming.in_flight_exit_finalized()
    |> common_parse_event(log)
  end

  def in_flight_exit_started(log) do
    function_spec = in_flight_exit_started()

    {_function_spec, data} =
      ABI.Event.find_and_decode(
        [function_spec],
        Encoding.from_hex(Enum.at(log["topics"], 0)),
        Encoding.from_hex(Enum.at(log["topics"], 1)),
        Encoding.from_hex(Enum.at(log["topics"], 2)),
        nil,
        Encoding.from_hex(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> HackNaming.in_flight_exit_started()
    |> common_parse_event(log)
  end

  def start_standard_exit(log) do
    function_spec = start_standard_exit()

    data =
      function_spec
      |> ABI.decode(log)
      |> hd()
      |> Tuple.to_list()

    function_spec.input_names
    |> Enum.zip(data)
    |> Enum.into(%{})
    |> HackNaming.start_standard_exit()
  end

  def start_in_flight_exit(log) do
    function_spec = start_in_flight_exit()

    data =
      function_spec
      |> ABI.decode(log)
      |> hd()
      |> Tuple.to_list()

    function_spec.input_names
    |> Enum.zip(data)
    |> Enum.into(%{})
    |> HackNaming.start_in_flight_exit()
  end

  #
  # selector definitions
  #
  defp deposit_created() do
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

  defp in_flight_exit_input_piggybacked() do
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

  defp in_flight_exit_output_piggybacked() do
    %ABI.FunctionSelector{
      function: "InFlightExitOutputPiggybacked",
      input_names: ["exitTarget", "txHash", "outputIndex"],
      inputs_indexed: [true, true, false],
      method_id: "n͎y",
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 16}]
    }
  end

  defp block_submitted() do
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

  defp exit_finalized() do
    %ABI.FunctionSelector{
      function: "ExitFinalized",
      input_names: ["exitId"],
      inputs_indexed: [true],
      method_id: <<10, 219, 41, 176>>,
      returns: [],
      type: :event,
      types: [uint: 160]
    }
  end

  defp in_flight_exit_challenged() do
    %ABI.FunctionSelector{
      function: "InFlightExitChallenged",
      input_names: ["challenger", "txHash", "challengeTxPosition"],
      inputs_indexed: [true, true, false],
      method_id: <<104, 116, 1, 150>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 256}]
    }
  end

  defp in_flight_exit_challenge_responded() do
    %ABI.FunctionSelector{
      function: "InFlightExitChallengeResponded",
      input_names: ["challenger", "txHash", "challengeTxPosition"],
      inputs_indexed: [true, true, false],
      method_id: "c|ħ",
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 256}]
    }
  end

  defp exit_challenged() do
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

  defp challenge_in_flight_exit_not_canonical() do
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

  defp in_flight_exit_input_blocked() do
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

  defp in_flight_exit_output_blocked() do
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

  defp in_flight_exit_input_withdrawn() do
    %ABI.FunctionSelector{
      function: "InFlightExitInputWithdrawn",
      input_names: ["exitId", "inputIndex"],
      inputs_indexed: [true, false],
      method_id: <<68, 70, 236, 17>>,
      returns: [],
      type: :event,
      types: [uint: 160, uint: 16]
    }
  end

  defp in_flight_exit_output_withdrawn() do
    %ABI.FunctionSelector{
      function: "InFlightExitOutputWithdrawn",
      input_names: ["exitId", "outputIndex"],
      inputs_indexed: [true, false],
      method_id: <<162, 65, 198, 222>>,
      returns: [],
      type: :event,
      types: [uint: 160, uint: 16]
    }
  end

  defp exit_started() do
    %ABI.FunctionSelector{
      function: "ExitStarted",
      input_names: ["owner", "exitId"],
      inputs_indexed: [true, false],
      method_id: <<221, 111, 117, 92>>,
      returns: [],
      type: :event,
      types: [:address, {:uint, 160}]
    }
  end

  defp in_flight_exit_started() do
    %ABI.FunctionSelector{
      function: "InFlightExitStarted",
      input_names: ["initiator", "txHash"],
      inputs_indexed: [true, true],
      method_id: <<213, 241, 254, 157>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}]
    }
  end

  defp start_standard_exit() do
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

  defp start_in_flight_exit() do
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

  def common_parse_event(
        result,
        %{"blockNumber" => eth_height, "transactionHash" => root_chain_txhash, "logIndex" => log_index} = event
      ) do
    # NOTE: we're using `put_new` here, because `merge` would allow us to overwrite data fields in case of conflict
    result
    |> Map.put_new(:eth_height, Encoding.int_from_hex(eth_height))
    |> Map.put_new(:root_chain_txhash, Encoding.from_hex(root_chain_txhash))
    |> Map.put_new(:log_index, Encoding.int_from_hex(log_index))
    # just copy `event_signature` over, if it's present (could use tidying up)
    |> Map.put_new(:event_signature, event[:event_signature])
  end
end
