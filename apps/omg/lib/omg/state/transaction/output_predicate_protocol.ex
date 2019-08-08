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

defmodule OMG.State.Transaction.OutputPredicateProtocol do
  @moduledoc """
  Code allowing outputs being spent by txs to be unlocked.

  Intended to be called in stateful validation
  """

  @doc """
  True if a particular witness can unlock a particular output to be spent, given being put in a particular transaction
  """
  def can_spend?(witness, output_spent, _raw_tx) when is_binary(witness) do
    output_spent.owner == witness
  end
end
