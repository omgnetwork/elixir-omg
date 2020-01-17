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
      outputs: [make_output(owner, currency, amount)],
      nonce: to_nonce(blknum, currency)
    }
  end

  @doc """
  Creates output for fee transaction
  """
  @spec make_output(owner :: Crypto.address_t(), currency :: Transaction.Payment.currency(), amount :: pos_integer()) ::
          Output.t()
  def make_output(owner, currency, amount) do
    %Output{
      owner: owner,
      currency: currency,
      amount: amount,
      output_type: @fee_token_claim_output_type
    }
  end

  @doc """
  Generates fee-txs to claim collected fees from the forming block
  """
  @spec claim_collected(
          blknum :: non_neg_integer(),
          owner :: Crypto.address_t(),
          fees_paid :: %{Crypto.address_t() => pos_integer()}
        ) :: list(t())
  def claim_collected(blknum, owner, fees_paid) do
    fees_paid
    |> Enum.reject(fn {_token, amount} -> amount == 0 end)
    |> Enum.map(fn {token, amount} -> new(blknum, {owner, token, amount}) end)
    |> Enum.sort_by(fn %__MODULE__{outputs: [output]} -> output.currency end)
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
  Tells whether Fee claiming transaction is valid
  """
  @spec valid?(Transaction.FeeTokenClaim.t(), Transaction.Signed.t()) :: {:error, atom()}
  def valid?(%Transaction.FeeTokenClaim{} = fee_tx, _signed_tx) do
    # we're able to check structure validity => single output with amount > 0
    with outputs = Transaction.get_outputs(fee_tx),
         true <- length(outputs) == 1 || {:error, :wrong_number_of_fee_outputs},
         [output] = outputs,
         true <- output.amount > 0 || {:error, :fee_output_amount_has_to_be_positive},
         do: true
  end

  @doc """
  Fee claiming transaction is not used to transfer funds
  """
  @spec can_apply?(Transaction.FeeTokenClaim.t(), list(Output.t())) :: {:ok, map()} | {:error, atom()}
  def can_apply?(%Transaction.FeeTokenClaim{outputs: [claimed]}, outputs) do
    with %Output{} = collected <-
           Enum.find(outputs, {:error, :surplus_in_token_not_collected}, fn o -> o.currency == claimed.currency end),
         true <- collected.amount == claimed.amount || {:error, :claimed_and_collected_amounts_mismatch},
         true <- collected.owner == claimed.owner || {:error, :only_fee_claimer_address_can_claim} do
      {:ok, %{collected.currency => collected.amount}}
    end
  end
end
