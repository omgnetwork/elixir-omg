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

defmodule OMG.Output do
  @moduledoc """
  `OMG.Output` and `OMG.Output.Protocol` represent the outputs of transactions, i.e. the valuables or other pieces of
  data spendable via transactions on the child chain, and/or exitable to the root chain.

  This module specificially dispatches generic calls to the various specific types
  """

  alias OMG.RawData

  @output_types_modules OMG.WireFormatTypes.output_type_modules()
  @output_types Map.keys(@output_types_modules)

  def dispatching_reconstruct([raw_type | rlp_decoded_chunks]) when is_binary(raw_type) do
    case RawData.parse_uint256(raw_type) do
      {:ok, output_type} when output_type in @output_types ->
        protocol_module = @output_types_modules[output_type]
        protocol_module.reconstruct([output_type | rlp_decoded_chunks])

      {:ok, _unrecognized_type} ->
        {:error, :unrecognized_output_type}
    end
  end

  def dispatching_reconstruct(what), do: {:error, :malformed_output}

  def from_db_value(%{type: output_type} = db_value), do: @output_types_modules[output_type].from_db_value(db_value)
  # default clause for backwards compatibility
  def from_db_value(%{} = db_value), do: OMG.Output.FungibleMoreVPToken.from_db_value(db_value)
end

defprotocol OMG.Output.Protocol do
  @moduledoc """
  Captures the varying behavior of outputs that build the plasma chain

  Includes the "output predicate", within the `can_spend?/3` function
  """

  @doc """
  True if a particular witness can unlock a particular output to be spent, given being put in a particular transaction

  Intended to be called in stateful validation
  """
  def can_spend?(output_spent, witness, raw_tx)

  @doc """
  Returns the input pointer that the output should be later referenced by in inputs to be spent
  """
  def input_pointer(output, blknum, tx_index, oindex, tx, hash)

  @doc """
  Transforms into a db-specific term
  """
  def to_db_value(output)

  @doc """
  Transforms into a RLP-ready structure
  """
  def get_data_for_rlp(output)
end
