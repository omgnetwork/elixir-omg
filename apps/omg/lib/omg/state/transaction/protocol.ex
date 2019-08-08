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

defprotocol OMG.State.Transaction.Protocol do
  @moduledoc """
  Should be implemented for any type of transaction processed in the system
  """

  alias OMG.State.Transaction

  @doc """
  Transforms structured data into RLP-structured (encodable) list of fields
  """
  @spec get_data_for_rlp(t()) :: list(any())
  def get_data_for_rlp(tx)

  @doc """
  List of input pointers (e.g. of which one implementation is `utxo_pos`) this transaction is intending to spend
  """
  @spec get_inputs(t()) :: list(any())
  def get_inputs(tx)

  @doc """
  List of outputs this transaction intends to create
  """
  @spec get_outputs(t()) :: list(any())
  def get_outputs(tx)

  @doc """
  Custom validation of the transaction with respect to its witnesses. Part of stateless validation routine
  """
  @spec valid?(t(), Transaction.Signed.t()) :: true | {:error, atom}
  def valid?(tx, signed_tx)

  @doc """
  Custom stateful validity, based on pre-fetched subset of input UTXOs

  Should also return the fees that this transaction is paying, mapped by currency; for fee validation
  """
  @spec can_apply?(t(), list()) :: {:ok, map()} | {:error, atom}
  def can_apply?(tx, input_utxos)
end
