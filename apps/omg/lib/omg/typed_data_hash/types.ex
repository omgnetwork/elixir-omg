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

defmodule OMG.TypedDataHash.Types do
  @moduledoc """
  Specifies all types needed to produce `eth_signTypedData` request.
  See: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#specification-of-the-eth_signtypeddata-json-rpc
  """

  @type typedDataSignRequest_t() :: %{
          types: map(),
          primaryType: binary(),
          domain: map(),
          message: map()
        }

  @make_spec &%{name: &1, type: &2}

  @eip_712_domain_spec [
    @make_spec.("name", "string"),
    @make_spec.("version", "string"),
    @make_spec.("verifyingContract", "address"),
    @make_spec.("salt", "bytes32")
  ]

  @tx_spec Enum.concat([
             [@make_spec.("txType", "uint256")],
             Enum.map(0..4, fn i -> @make_spec.("input" <> Integer.to_string(i), "Input") end),
             Enum.map(0..4, fn i -> @make_spec.("output" <> Integer.to_string(i), "Output") end),
             [@make_spec.("txData", "uint256")],
             [@make_spec.("metadata", "bytes32")]
           ])

  @input_spec [
    @make_spec.("blknum", "uint256"),
    @make_spec.("txindex", "uint256"),
    @make_spec.("oindex", "uint256")
  ]

  @output_spec [
    @make_spec.("outputType", "uint256"),
    @make_spec.("outputGuard", "bytes20"),
    @make_spec.("currency", "address"),
    @make_spec.("amount", "uint256")
  ]

  @types %{
    EIP712Domain: @eip_712_domain_spec,
    Transaction: @tx_spec,
    Input: @input_spec,
    Output: @output_spec
  }

  def eip712_types_specification(),
    do: %{
      types: @types,
      primaryType: "Transaction"
    }

  def encode_type(type_name) when is_atom(type_name) do
    "#{type_name}(#{
      @types[type_name]
      |> Enum.map(fn %{name: name, type: type} -> "#{type} #{name}" end)
      |> Enum.join(",")
    })"
  end
end
