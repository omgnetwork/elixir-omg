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

defmodule OMG.InputPointer do
  @moduledoc """
  `OMG.InputPointer` and `OMG.InputPointer.Protocol` represent the data that's used to mention outputs that are intended
  to be inputs to a transaction. Examples are UTXO positions or output id (consisting of transaction hash and output
  index)

  This module specificially dispatches generic calls to the various specific types
  """
  @input_pointer_types_modules Application.fetch_env!(:omg, :input_pointer_types_modules)

  def from_db_key({:input_pointer, type_marker, db_value}),
    do: @input_pointer_types_modules[type_marker].from_db_key(db_value)

  # default clause for backwards compatibility
  def from_db_key(db_value), do: OMG.InputPointer.UtxoPosition.from_db_key(db_value)
end

defprotocol OMG.InputPointer.Protocol do
  @moduledoc """
  Captures the varying behavior of how the outputs can be pointed to in child chain transactions
  """

  @doc """
  Transforms into a db-specific term
  """
  def to_db_key(input_pointer)

  @doc """
  Transforms into a RLP-ready structure
  """
  def get_data_for_rlp(input_pointer)
end
