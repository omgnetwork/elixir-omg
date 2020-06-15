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

defmodule OMG.State.Transaction.Payment.Builder do
  @moduledoc """
  Module to build payment tx of different tx types. (eg. v1 and v2)
  """

  alias OMG.Crypto
  alias OMG.Output
  alias OMG.State.Transaction
  alias OMG.State.Transaction.Payment
  alias OMG.Utxo

  require Transaction
  require Utxo

  @max_inputs 4
  @max_outputs 4
  @zero_metadata <<0::256>>

  @payment_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v1)
  @payment_output_type OMG.WireFormatTypes.output_type_for(:output_payment_v1)

  @payment_v2_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v2)
  @payment_v2_output_type OMG.WireFormatTypes.output_type_for(:output_payment_v2)

  @output_types %{
    @payment_tx_type => @payment_output_type,
    @payment_v2_tx_type => @payment_v2_output_type
  }

  @doc """
  Creates a new raw transaction structure from a list of inputs and a list of outputs, given in a succinct tuple form.

  assumptions:
  ```
    length(inputs) <= @max_inputs
    length(outputs) <= @max_outputs
  ```
  """
  @spec new_payment(
          pos_integer,
          list({pos_integer, pos_integer, 0..unquote(@max_outputs - 1)}),
          list({Crypto.address_t(), Payment.currency(), pos_integer}),
          Transaction.metadata()
        ) :: Payment.t()
  def new_payment(tx_type, inputs, outputs, metadata \\ @zero_metadata)
      when Transaction.is_metadata(metadata) and length(inputs) <= @max_inputs and length(outputs) <= @max_outputs do
    inputs = Enum.map(inputs, &new_input/1)
    outputs = Enum.map(outputs, fn output -> new_output(output, @output_types[tx_type]) end)
    %Transaction.Payment{tx_type: tx_type, inputs: inputs, outputs: outputs, metadata: metadata}
  end

  # `new_input/1` and `new_output/1` are here to just help interpret the short-hand form of inputs outputs when doing
  # `new/3`
  defp new_input({blknum, txindex, oindex}), do: Utxo.position(blknum, txindex, oindex)

  defp new_output({owner, currency, amount}, output_type) do
    %Output{
      owner: owner,
      currency: currency,
      amount: amount,
      output_type: output_type
    }
  end
end
