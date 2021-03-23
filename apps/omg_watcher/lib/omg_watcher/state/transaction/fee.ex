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

defmodule OMG.Watcher.State.Transaction.Fee do
  @moduledoc """
  Internal representation of a fee claiming transaction in plasma chain.
  """
  alias OMG.Output
  alias OMG.Watcher.Crypto
  alias OMG.Watcher.State.Transaction

  require Transaction

  @fee_token_claim_tx_type OMG.Watcher.WireFormatTypes.tx_type_for(:tx_fee_token_claim)
  @fee_token_claim_output_type OMG.Watcher.WireFormatTypes.output_type_for(:output_fee_token_claim)

  defstruct [:tx_type, :outputs, :nonce]

  @type t() :: %__MODULE__{
          tx_type: non_neg_integer(),
          outputs: [Output.t()],
          nonce: Crypto.hash_t()
        }

  @doc """
  Creates new fee claiming transaction
  """
  @spec new(
          blknum :: non_neg_integer(),
          {Crypto.address_t(), Transaction.Payment.currency(), pos_integer}
        ) :: t()
  def new(blknum, {owner, currency, amount}) do
    %__MODULE__{
      tx_type: @fee_token_claim_tx_type,
      outputs: [new_output(owner, currency, amount)],
      nonce: to_nonce(blknum, currency)
    }
  end

  @doc """
  Creates output for fee transaction
  """
  @spec new_output(owner :: Crypto.address_t(), currency :: Transaction.Payment.currency(), amount :: pos_integer()) ::
          Output.t()
  def new_output(owner, currency, amount) do
    %Output{
      owner: owner,
      currency: currency,
      amount: amount,
      output_type: @fee_token_claim_output_type
    }
  end

  @doc """
  Transforms the structure of RLP items after a successful RLP decode of a raw transaction, into a structure instance
  """
  def reconstruct([tx_type, outputs_rlp, nonce_rlp]) do
    with {:ok, outputs} <- reconstruct_outputs(outputs_rlp),
         {:ok, nonce} <- reconstruct_nonce(nonce_rlp),
         do: {:ok, %__MODULE__{tx_type: tx_type, outputs: outputs, nonce: nonce}}
  end

  def reconstruct(_), do: {:error, :malformed_transaction}

  defp reconstruct_outputs(outputs_rlp) do
    outputs = Enum.map(outputs_rlp, &Output.reconstruct/1)

    with nil <- Enum.find(outputs, &match?({:error, _}, &1)),
         true <- only_allowed_output_types?(outputs) || {:error, :tx_cannot_create_output_type},
         do: {:ok, outputs}
  rescue
    _ -> {:error, :malformed_outputs}
  end

  defp reconstruct_nonce(nonce) when is_binary(nonce) and byte_size(nonce) == 32, do: {:ok, nonce}
  defp reconstruct_nonce(_), do: {:error, :malformed_nonce}

  defp only_allowed_output_types?([%Output{}]), do: true
  defp only_allowed_output_types?(_), do: false

  @spec to_nonce(non_neg_integer(), Transaction.Payment.currency()) :: Crypto.hash_t()
  defp to_nonce(blknum, token) do
    blknum_bytes = ABI.TypeEncoder.encode_raw([blknum], [{:uint, 256}])
    token_bytes = ABI.TypeEncoder.encode_raw([token], [:address])

    Crypto.hash(blknum_bytes <> token_bytes)
  end
end

defimpl OMG.Watcher.State.Transaction.Protocol, for: OMG.Watcher.State.Transaction.Fee do
  alias OMG.Output
  alias OMG.Watcher.State.Transaction

  @doc """
  Turns a structure instance into a structure of RLP items, ready to be RLP encoded, for a raw transaction
  """
  @spec get_data_for_rlp(Transaction.Fee.t()) :: list(any())
  def get_data_for_rlp(%Transaction.Fee{tx_type: tx_type, outputs: outputs, nonce: nonce}) do
    [
      tx_type,
      Enum.map(outputs, &Output.get_data_for_rlp/1),
      nonce
    ]
  end

  @doc """
  Fee claiming transaction spends single pseudo-output from collected fees.
  """
  @spec get_outputs(Transaction.Fee.t()) :: list(Output.t())
  def get_outputs(%Transaction.Fee{outputs: outputs}), do: outputs

  @doc """
  Fee claiming transaction does not contain any inputs.
  """
  @spec get_inputs(Transaction.Fee.t()) :: list(OMG.Watcher.Utxo.Position.t())
  def get_inputs(%Transaction.Fee{}), do: []

  @doc """
  Tells whether Fee claiming transaction is valid
  """
  @spec valid?(Transaction.Fee.t(), Transaction.Signed.t()) ::
          {:error, :wrong_number_of_fee_outputs | :fee_output_amount_has_to_be_positive}
  def valid?(%Transaction.Fee{} = fee_tx, _signed_tx) do
    # we're able to check structure validity => single output with amount > 0
    outputs = Transaction.get_outputs(fee_tx)

    with true <- length(outputs) == 1 || {:error, :wrong_number_of_fee_outputs},
         [output] = outputs,
         true <- output.amount > 0 || {:error, :fee_output_amount_has_to_be_positive},
         do: true
  end

  @doc """
  Fee claiming transaction is not used to transfer funds
  """
  @spec can_apply?(Transaction.Fee.t(), list(Output.t())) ::
          {:ok, map()}
          | {:error, :surplus_in_token_not_collected | :claimed_and_collected_amounts_mismatch}
  def can_apply?(%Transaction.Fee{outputs: [claimed]}, outputs) do
    with %Output{} = collected <- find_output_by_currency(outputs, claimed.currency),
         true <- amounts_equal?(collected.amount, claimed.amount),
         do: {:ok, %{}}
  end

  defp find_output_by_currency(outputs, currency),
    do: Enum.find(outputs, {:error, :surplus_in_token_not_collected}, fn o -> o.currency == currency end)

  defp amounts_equal?(collected, claimed) when collected == claimed, do: true
  defp amounts_equal?(_, _), do: {:error, :claimed_and_collected_amounts_mismatch}
end
