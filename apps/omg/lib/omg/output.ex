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

defprotocol OMG.Output do
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
  True if this particular output can and should be completely disregarded
  """
  def is_zero?(output)

  @doc """
  Transforms into a db-specific term
  """
  def to_db_value(output)

  @doc """
  Restores from a db-specific term
  """
  def from_db_value(type, db_value)
end
