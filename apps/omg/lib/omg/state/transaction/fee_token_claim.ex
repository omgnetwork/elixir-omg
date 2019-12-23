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

defmodule OMG.State.Transaction.FeeTokenClaim do
  @moduledoc """
  Internal representation of a fee claiming transaction in plasma chain.
  """
  alias OMG.Crypto
  alias OMG.Output
  alias OMG.State.Transaction

  require Transaction

  @fee_token_claim_tx_type OMG.WireFormatTypes.tx_type_for(:tx_fee_token_claim)
  @fee_token_claim_output_type OMG.WireFormatTypes.output_type_for(:output_fee_token_claim)

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
      outputs: [
        %Output{
          owner: owner,
          currency: currency,
          amount: amount,
          output_type: @fee_token_claim_output_type
        }
      ],
      nonce: to_nonce(blknum, currency)
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

defimpl OMG.State.Transaction.Protocol, for: OMG.State.Transaction.FeeTokenClaim do
  alias OMG.Output
  alias OMG.State.Transaction

  @doc """
  Turns a structure instance into a structure of RLP items, ready to be RLP encoded, for a raw transaction
  """
  @spec get_data_for_rlp(Transaction.FeeTokenClaim.t()) :: list(any())
  def get_data_for_rlp(%Transaction.FeeTokenClaim{tx_type: tx_type, outputs: outputs, nonce: nonce}) do
    [
      tx_type,
      Enum.map(outputs, &OMG.Output.get_data_for_rlp/1),
      nonce
    ]
  end

  @spec get_outputs(Transaction.FeeTokenClaim.t()) :: list(Output.t())
  def get_outputs(%Transaction.FeeTokenClaim{outputs: outputs}), do: outputs

  @spec get_inputs(Transaction.FeeTokenClaim.t()) :: list(OMG.Utxo.Position.t())
  def get_inputs(%Transaction.FeeTokenClaim{}), do: []

  @doc """
  Fee claiming transaction is not used to transfer funds
  """
  @spec valid?(Transaction.FeeTokenClaim.t(), Transaction.Signed.t()) :: {:error, atom()}
  def valid?(%Transaction.FeeTokenClaim{}, _signed_tx), do: {:error, :not_implemented}

  @doc """
  Fee claiming transaction is not used to transfer funds
  """
  @spec can_apply?(Transaction.FeeTokenClaim.t(), list(Output.t())) :: {:error, atom()}
  def can_apply?(%Transaction.FeeTokenClaim{}, _outputs_spent), do: {:error, :not_implemented}
end
