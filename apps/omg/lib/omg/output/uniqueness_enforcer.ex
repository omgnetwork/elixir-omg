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

defmodule OMG.Output.UniquenessEnforcer do
  @moduledoc """
  Output to enforce transaction's hash uniqueness based on plasma block number.
  """
  defstruct [:blknum, :type_marker]

  @type t :: %__MODULE__{
          blknum: non_neg_integer(),
          type_marker: binary()
        }

  def reconstruct([type_marker, blknum])
      when is_integer(blknum) and is_binary(type_marker),
      do: %__MODULE__{blknum: parse_int!(blknum), type_marker: type_marker}

  defp parse_int!(binary), do: :binary.decode_unsigned(binary, :big)
end

defimpl OMG.Output.Protocol, for: OMG.Output.UniquenessEnforcer do
  alias OMG.Output.UniquenessEnforcer

  @doc """
  For payment outputs, a binary witness is assumed to be a signature equal to the payment's output owner
  """
  def can_spend?(%UniquenessEnforcer{}, _witness, _raw_tx), do: false

  def input_pointer(%UniquenessEnforcer{}, _blknum, _txindex, _oindex, _, _),
    do: exit(:output_cannot_be_tx_input)

  def to_db_value(%UniquenessEnforcer{blknum: blknum, type_marker: type_marker}),
    do: %{blknum: blknum, type_marker: type_marker}

  def get_data_for_rlp(%UniquenessEnforcer{blknum: blknum, type_marker: type_marker}),
    do: [type_marker, blknum]
end
