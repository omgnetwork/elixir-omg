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

defmodule OMG.WireFormatTypes do
  @moduledoc """
  Provides wire format's tx/output type values and mapping to modules which decodes them.
  """

  @type module_map_t() :: %{non_neg_integer() => atom()}

  @tx_type_values %{
    tx_payment_v1: 1,
    tx_fee_token_claim: 3
  }

  @tx_type_modules %{
    1 => OMG.State.Transaction.Payment,
    3 => OMG.State.Transaction.FeeTokenClaim
  }

  @input_pointer_type_values %{
    input_pointer_utxo_position: 1
  }

  @input_pointer_type_modules %{
    1 => OMG.InputPointer.UtxoPosition
  }

  @output_type_values %{
    output_payment_v1: 1,
    output_fee_token_claim: 2
  }

  @output_type_modules %{
    1 => OMG.Output.FungibleMoreVPToken,
    2 => OMG.Output.FungibleMoreVPToken
  }

  @known_tx_types Map.keys(@tx_type_values)
  @known_input_pointer_types Map.keys(@input_pointer_type_values)
  @known_output_types Map.keys(@output_type_values)

  @doc """
  Returns wire format type value of known transaction type
  """
  @spec tx_type_for(tx_type :: atom()) :: non_neg_integer()
  def tx_type_for(tx_type) when tx_type in @known_tx_types, do: @tx_type_values[tx_type]

  @doc """
  Returns module atom that is able to decode transaction of given type
  """
  @spec tx_type_modules() :: module_map_t()
  def tx_type_modules, do: @tx_type_modules

  @doc """
  Returns wire format type value of known input pointer type
  """
  @spec input_pointer_type_for(input_pointer_type :: atom()) :: non_neg_integer()
  def input_pointer_type_for(input_pointer_type) when input_pointer_type in @known_input_pointer_types,
    do: @input_pointer_type_values[input_pointer_type]

  @doc """
  Returns module atom that is able to decode input pointer of given type
  """
  @spec input_pointer_type_modules() :: module_map_t()
  def input_pointer_type_modules, do: @input_pointer_type_modules

  @doc """
  Returns wire format type value of known output type
  """
  @spec output_type_for(output_type :: atom()) :: non_neg_integer()
  def output_type_for(output_type) when output_type in @known_output_types, do: @output_type_values[output_type]

  @doc """
  Returns module atom that is able to decode output of given type
  """
  @spec output_type_modules() :: module_map_t()
  def output_type_modules, do: @output_type_modules
end
