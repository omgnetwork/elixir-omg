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

defmodule OMG.TypedDataHash.Types do
  @moduledoc """
  Specifies all types needed to produce `eth_signTypedData` request.
  See: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#specification-of-the-eth_signtypeddata-json-rpc
  """

  import OMG.TypedDataHash.SpecHelper

  @eip_712_domain_spec [
    spec("name", "string"),
    spec("version", "string"),
    spec("verifyingContract", "address"),
    spec("salt", "bytes32")
  ]

  @tx_spec Enum.map(0..3, fn i -> spec("input#{i}", "Input") end) ++
             Enum.map(0..3, fn i -> spec("output#{i}", "Output") end) ++
             [spec("metadata", "bytes32")]

  @input_spec [
    spec("blknum", "uint256"),
    spec("txindex", "uint256"),
    spec("oindex", "uint256")
  ]

  @output_spec [
    spec("owner", "address"),
    spec("currency", "address"),
    spec("amount", "uint256")
  ]

  def eip712_types_specification,
    do: [
      types: %{
        EIP712Domain: @eip_712_domain_spec,
        Transaction: @tx_spec,
        Input: @input_spec,
        Output: @output_spec
      },
      primaryType: "Transaction"
    ]
end
