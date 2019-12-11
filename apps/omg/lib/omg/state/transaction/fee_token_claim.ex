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

  # TODO: figure out how to nicely reference markers map from config
  @fee_output_type_marker <<2>>

  defstruct [:outputs, :nonce]

  @type t() :: %__MODULE__{outputs: [Output.FungibleMoreVPToken.t()], nonce: Crypto.hash_t()}

  @doc """
  Creates new fee claiming transaction
  """
  @spec new(
          blknum :: non_neg_integer(),
          {Crypto.address_t(), Transaction.Payment.currency(), pos_integer}
        ) :: t()
  def new(blknum, {owner, currency, amount}) do
    %__MODULE__{
      outputs: [
        %Output.FungibleMoreVPToken{
          owner: owner,
          currency: currency,
          amount: amount,
          type_marker: @fee_output_type_marker
        }
      ],
      nonce: to_nonce(blknum, currency)
    }
  end

  @doc """
  Transaform the structure of RLP items after a successful RLP decode of a raw transaction, into a structure instance
  """
  def reconstruct([outputs_rlp, nonce_rlp]) do
    with {:ok, outputs} <- reconstruct_outputs(outputs_rlp),
         {:ok, nonce} <- reconstruct_nonce(nonce_rlp),
         do: {:ok, %__MODULE__{outputs: outputs, nonce: nonce}}
  end

  def reconstruct(_), do: {:error, :malformed_transaction}

  defp reconstruct_outputs(outputs_rlp) do
    outputs = Enum.map(outputs_rlp, &Output.dispatching_reconstruct/1)

    with nil <- Enum.find(outputs, &match?({:error, _}, &1)),
         true <- only_allowed_output_types?(outputs) || {:error, :tx_cannot_create_output_type},
         do: {:ok, outputs}
  rescue
    _ -> {:error, :malformed_outputs}
  end

  defp reconstruct_nonce(nonce) when Transaction.is_metadata(nonce), do: {:ok, nonce}
  defp reconstruct_nonce(_), do: {:error, :malformed_nonce}

  defp only_allowed_output_types?([%Output.FungibleMoreVPToken{}]), do: true
  defp only_allowed_output_types?(_), do: false

  @spec to_nonce(non_neg_integer(), Transaction.Payment.currency()) :: Crypto.hash_t()
  defp to_nonce(blknum, token) do
    blknum_bytes = ABI.TypeEncoder.encode_raw([blknum], [{:uint, 256}])
    token_bytes = ABI.TypeEncoder.encode_raw([token], [:address])

    Crypto.hash(blknum_bytes <> token_bytes)
  end
end

defimpl OMG.State.Transaction.Protocol, for: OMG.State.Transaction.FeeTokenClaim do
  alias OMG.InputPointer
  alias OMG.Output
  alias OMG.State.Transaction

  # TODO: figure out how to nicely reference markers map from config
  @fee_tx_type_marker <<3>>

  @doc """
  Turns a structure instance into a structure of RLP items, ready to be RLP encoded, for a raw transaction
  """
  @spec get_data_for_rlp(Transaction.FeeTokenClaim.t()) :: list(any())
  def get_data_for_rlp(%Transaction.FeeTokenClaim{outputs: outputs, nonce: nonce}),
    do: [
      @fee_tx_type_marker,
      Enum.map(outputs, &OMG.Output.Protocol.get_data_for_rlp/1),
      nonce
    ]

  @spec get_outputs(Transaction.FeeTokenClaim.t()) :: list(Output.Protocol.t())
  def get_outputs(%Transaction.FeeTokenClaim{outputs: outputs}), do: outputs

  @spec get_inputs(Transaction.FeeTokenClaim.t()) :: list(InputPointer.Protocol.t())
  def get_inputs(%Transaction.FeeTokenClaim{}), do: []

  @doc """
  Fee claiming transaction is not used to transfer funds
  """
  @spec valid?(Transaction.FeeTokenClaim.t(), Transaction.Signed.t()) :: {:error, atom()}
  def valid?(%Transaction.FeeTokenClaim{}, _signed_tx), do: {:error, :transaction_not_transfer_funds}

  @doc """
  Fee claiming transaction is not used to transfer funds
  """
  @spec can_apply?(Transaction.FeeTokenClaim.t(), list(Output.Protocol.t())) :: {:error, atom()}
  def can_apply?(%Transaction.FeeTokenClaim{}, _outputs_spent), do: {:error, :transaction_not_transfer_funds}
end
