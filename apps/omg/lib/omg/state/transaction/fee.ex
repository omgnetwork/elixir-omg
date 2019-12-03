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

defmodule OMG.State.Transaction.Fee do
  @moduledoc """
  Internal representation of a raw payment transaction done on Plasma chain.

  This module holds the representation of a "raw" transaction, i.e. without signatures nor recovered input spenders
  """
  alias OMG.Crypto
  alias OMG.Output
  alias OMG.State.Transaction

  @fee_output_type_marker <<0xFE, 0xE0>>
  @uniqueness_output_type_marker <<0xF0, 0x0F>>

  defstruct [:outputs]

  @type t() :: %__MODULE__{outputs: [Output.FungibleMoreVPToken.t() | Output.UniquenessEnforcer.t()]}

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
        %Output.UniquenessEnforcer{blknum: blknum, type_marker: @uniqueness_output_type_marker},
        %Output.FungibleMoreVPToken{
          owner: owner,
          currency: currency,
          amount: amount,
          type_marker: @fee_output_type_marker
        }
      ]
    }
  end

  @doc """
  Transaform the structure of RLP items after a successful RLP decode of a raw transaction, into a structure instance
  """
  def reconstruct([outputs_rlp]) do
    with {:ok, outputs} <- reconstruct_outputs(outputs_rlp),
         do: {:ok, %__MODULE__{outputs: outputs}}
  end

  def reconstruct(_), do: {:error, :malformed_transaction}

  defp reconstruct_outputs(outputs_rlp) do
    with {:ok, outputs} <- parse_outputs(outputs_rlp),
         do: {:ok, outputs}
  end

  defp parse_outputs(outputs_rlp) do
    outputs = Enum.map(outputs_rlp, &Output.dispatching_reconstruct/1)

    with nil <- Enum.find(outputs, &match?({:error, _}, &1)),
         true <- only_allowed_output_types?(outputs) || {:error, :tx_cannot_create_output_type},
         do: {:ok, outputs}
  rescue
    _ -> {:error, :malformed_outputs}
  end

  defp only_allowed_output_types?([%Output.UniquenessEnforcer{}, %Output.FungibleMoreVPToken{}]), do: true
  defp only_allowed_output_types?(_), do: false
end

defimpl OMG.State.Transaction.Protocol, for: OMG.State.Transaction.Fee do
  alias OMG.InputPointer
  alias OMG.Output
  alias OMG.State.Transaction

  @fee_tx_type_marker <<0xFE, 0xE0>>

  @doc """
  Turns a structure instance into a structure of RLP items, ready to be RLP encoded, for a raw transaction
  """
  @spec get_data_for_rlp(Transaction.Fee.t()) :: list(any())
  def get_data_for_rlp(%Transaction.Fee{outputs: outputs}),
    do: [
      @fee_tx_type_marker,
      Enum.map(outputs, &OMG.Output.Protocol.get_data_for_rlp/1)
    ]

  @spec get_outputs(Transaction.Fee.t()) :: list(Output.Protocol.t())
  def get_outputs(%Transaction.Fee{outputs: outputs}), do: outputs

  @spec get_inputs(Transaction.Fee.t()) :: list(InputPointer.Protocol.t())
  def get_inputs(%Transaction.Fee{}), do: []

  @doc """
  Fee claiming transaction is not used to transfer funds
  """
  @spec valid?(Transaction.Fee.t(), Transaction.Signed.t()) :: {:error, atom}
  def valid?(%Transaction.Fee{}, _signed_tx), do: {:error, :tx_is_not_payment}

  @doc """
  Fee claiming transaction is not used to transfer funds
  """
  @spec can_apply?(Transaction.Fee.t(), list(Output.Protocol.t())) :: {:error, :tx_is_not_payment}
  def can_apply?(%Transaction.Fee{}, _outputs_spent), do: {:error, :tx_is_not_payment}
end
