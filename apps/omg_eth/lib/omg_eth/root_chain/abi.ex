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
defmodule OMG.Eth.RootChain.Abi do
  @moduledoc """
  Functions that provide ethereum log decoding
  """
  alias OMG.Eth.Encoding
  alias OMG.Eth.RootChain.AbiEventSelector
  alias OMG.Eth.RootChain.AbiFunctionSelector
  alias OMG.Eth.RootChain.Fields

  def decode_function(enriched_data, signature) do
    "0x" <> data = enriched_data
    <<method_id::binary-size(4), _::binary>> = :keccakf1600.hash(:sha3_256, signature)
    method_id |> Encoding.to_hex() |> Kernel.<>(data) |> Encoding.from_hex() |> decode_function()
  end

  def decode_function(enriched_data) do
    function_specs =
      Enum.reduce(AbiFunctionSelector.module_info(:exports), [], fn
        {:module_info, 0}, acc -> acc
        {function, 0}, acc -> [apply(AbiFunctionSelector, function, []) | acc]
        _, acc -> acc
      end)

    case ABI.find_and_decode(function_specs, enriched_data) do
      {:error, _} = e -> e
      {function_spec, data} -> decode_function_call_result(function_spec, data)
    end
  end

  def decode_log(log) do
    event_specs =
      Enum.reduce(AbiEventSelector.module_info(:exports), [], fn
        {:module_info, 0}, acc -> acc
        {function, 0}, acc -> [apply(AbiEventSelector, function, []) | acc]
        _, acc -> acc
      end)

    topics =
      Enum.map(log["topics"], fn
        nil -> nil
        topic -> Encoding.from_hex(topic)
      end)

    data = Encoding.from_hex(log["data"])

    {event_spec, data} =
      ABI.Event.find_and_decode(
        event_specs,
        Enum.at(topics, 0),
        Enum.at(topics, 1),
        Enum.at(topics, 2),
        Enum.at(topics, 3),
        data
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> Fields.rename(event_spec)
    |> common_parse_event(log)
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

  defp decode_function_call_result(function_spec, [values]) when is_tuple(values) do
    function_spec.input_names
    |> Enum.zip(Tuple.to_list(values))
    |> Enum.into(%{})
    |> Fields.rename(function_spec)
  end

  # workaround for https://github.com/omgnetwork/elixir-omg/issues/1632
  defp decode_function_call_result(%{function: "startExit"} = function_spec, values) do
    function_spec.input_names
    |> Enum.zip(values)
    |> Enum.into(%{})
    |> Fields.rename(function_spec)
  end

  defp decode_function_call_result(function_spec, values) do
    function_spec.input_names
    |> Enum.zip(values)
    |> Enum.into(%{})
  end
end
