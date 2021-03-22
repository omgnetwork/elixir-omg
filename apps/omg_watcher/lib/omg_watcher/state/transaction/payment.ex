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

defmodule OMG.Watcher.State.Transaction.Payment do
  @moduledoc """
  Internal representation of a raw payment transaction done on Plasma chain.

  This module holds the representation of a "raw" transaction, i.e. without signatures nor recovered input spenders
  """
  alias OMG.Watcher.Crypto

  alias OMG.Output
  alias OMG.Watcher.RawData
  alias OMG.Watcher.State.Transaction
  alias OMG.Watcher.Utxo

  require Transaction
  require Utxo

  @zero_metadata <<0::256>>
  @payment_tx_type OMG.Watcher.WireFormatTypes.tx_type_for(:tx_payment_v1)
  @payment_output_type OMG.Watcher.WireFormatTypes.output_type_for(:output_payment_v1)

  defstruct [:tx_type, :inputs, :outputs, metadata: @zero_metadata]

  @type t() :: %__MODULE__{
          tx_type: non_neg_integer(),
          inputs: list(OMG.Watcher.Utxo.Position.t()),
          outputs: list(Output.t()),
          metadata: Transaction.metadata()
        }

  @type currency() :: Crypto.address_t()

  @max_inputs 4
  @max_outputs 4

  defmacro max_inputs() do
    quote do
      unquote(@max_inputs)
    end
  end

  defmacro max_outputs() do
    quote do
      unquote(@max_outputs)
    end
  end

  @doc """
  Creates a new raw transaction structure from a list of inputs and a list of outputs, given in a succinct tuple form.

  assumptions:
  ```
    length(inputs) <= @max_inputs
    length(outputs) <= @max_outputs
  ```
  """
  @spec new(
          list({pos_integer, pos_integer, 0..unquote(@max_outputs - 1)}),
          list({Crypto.address_t(), currency(), pos_integer}),
          Transaction.metadata()
        ) :: t()
  def new(inputs, outputs, metadata \\ @zero_metadata)

  def new(inputs, outputs, metadata)
      when Transaction.is_metadata(metadata) and length(inputs) <= @max_inputs and length(outputs) <= @max_outputs do
    inputs = Enum.map(inputs, &new_input/1)
    outputs = Enum.map(outputs, &new_output/1)
    %__MODULE__{tx_type: @payment_tx_type, inputs: inputs, outputs: outputs, metadata: metadata}
  end

  @doc """
  Transforms the structure of RLP items after a successful RLP decode of a raw transaction, into a structure instance
  """
  def reconstruct([tx_type, inputs_rlp, outputs_rlp, tx_data_rlp, metadata_rlp]) do
    with {:ok, inputs} <- reconstruct_inputs(inputs_rlp),
         {:ok, outputs} <- reconstruct_outputs(outputs_rlp),
         {:ok, tx_data} <- RawData.parse_uint256(tx_data_rlp),
         :ok <- check_tx_data(tx_data),
         {:ok, metadata} <- reconstruct_metadata(metadata_rlp),
         do: {:ok, %__MODULE__{tx_type: tx_type, inputs: inputs, outputs: outputs, metadata: metadata}}
  end

  def reconstruct(_), do: {:error, :malformed_transaction}

  # `new_input/1` and `new_output/1` are here to just help interpret the short-hand form of inputs outputs when doing
  # `new/3`
  defp new_input({blknum, txindex, oindex}), do: Utxo.position(blknum, txindex, oindex)

  defp new_output({owner, currency, amount}) do
    %Output{
      owner: owner,
      currency: currency,
      amount: amount,
      output_type: @payment_output_type
    }
  end

  defp reconstruct_inputs(inputs_rlp) do
    with {:ok, inputs} <- parse_inputs(inputs_rlp),
         do: {:ok, inputs}
  end

  defp reconstruct_outputs([]), do: {:error, :empty_outputs}

  defp reconstruct_outputs(outputs_rlp) do
    with {:ok, outputs} <- parse_outputs(outputs_rlp),
         do: {:ok, outputs}
  end

  # txData is required to be zero in the contract
  defp check_tx_data(0), do: :ok
  defp check_tx_data(_), do: {:error, :malformed_tx_data}

  defp reconstruct_metadata(metadata) when Transaction.is_metadata(metadata), do: {:ok, metadata}
  defp reconstruct_metadata(_), do: {:error, :malformed_metadata}

  defp parse_inputs(inputs_rlp) do
    with true <- Enum.count(inputs_rlp) <= @max_inputs || {:error, :too_many_inputs},
         # NOTE: workaround for https://github.com/omgnetwork/ex_plasma/issues/19.
         #       remove, when this is blocked on `ex_plasma` end
         true <- Enum.all?(inputs_rlp, &(&1 != <<0::256>>)) || {:error, :malformed_inputs},
         do: {:ok, Enum.map(inputs_rlp, &parse_input!/1)}
  rescue
    _ -> {:error, :malformed_inputs}
  end

  defp parse_outputs(outputs_rlp) do
    outputs = Enum.map(outputs_rlp, &Output.reconstruct/1)

    with true <- Enum.count(outputs) <= @max_outputs || {:error, :too_many_outputs},
         nil <- Enum.find(outputs, &match?({:error, _}, &1)),
         true <- only_allowed_output_types?(outputs) || {:error, :tx_cannot_create_output_type},
         do: {:ok, outputs}
  rescue
    _ -> {:error, :malformed_outputs}
  end

  defp only_allowed_output_types?(outputs),
    do: Enum.all?(outputs, &match?(%Output{}, &1))

  defp parse_input!(encoded), do: OMG.Watcher.Utxo.Position.decode!(encoded)
end

defimpl OMG.Watcher.State.Transaction.Protocol, for: OMG.Watcher.State.Transaction.Payment do
  alias OMG.Output
  alias OMG.Watcher.State.Transaction
  alias OMG.Watcher.Utxo

  require Transaction
  require Utxo

  @empty_signature <<0::size(520)>>

  @doc """
  Turns a structure instance into a structure of RLP items, ready to be RLP encoded, for a raw transaction
  """
  @spec get_data_for_rlp(Transaction.Payment.t()) :: list(any())
  def get_data_for_rlp(%Transaction.Payment{tx_type: tx_type, inputs: inputs, outputs: outputs, metadata: metadata})
      when Transaction.is_metadata(metadata),
      do: [
        tx_type,
        Enum.map(inputs, &OMG.Watcher.Utxo.Position.get_data_for_rlp/1),
        Enum.map(outputs, &Output.get_data_for_rlp/1),
        # used to be optional and as such was `if`-appended if not null here
        # When it is not optional, and there's the if, dialyzer complains about the if
        0,
        metadata
      ]

  @spec get_outputs(Transaction.Payment.t()) :: list(Output.t())
  def get_outputs(%Transaction.Payment{outputs: outputs}), do: outputs

  @spec get_inputs(Transaction.Payment.t()) :: list(OMG.Watcher.Utxo.Position.t())
  def get_inputs(%Transaction.Payment{inputs: inputs}), do: inputs

  @doc """
  True if the witnessses provided follow some extra custom validation.

  Currently this covers the requirement for all the inputs to be signed on predetermined positions
  """
  @spec valid?(Transaction.Payment.t(), Transaction.Signed.t()) :: true | {:error, atom}
  def valid?(%Transaction.Payment{}, %Transaction.Signed{sigs: sigs} = tx) do
    tx
    |> Transaction.get_inputs()
    |> all_inputs_signed?(sigs)
  end

  @doc """
  True if a payment can be applied, given a set of input UTXOs is present in the ledger.
  Involves the checking of balancing of inputs and outputs for currencies

  Returns the fees that this transaction is paying, mapped by currency
  """
  @spec can_apply?(Transaction.Payment.t(), list(Output.t())) ::
          {:ok, map()} | {:error, :amounts_do_not_add_up}
  def can_apply?(%Transaction.Payment{} = tx, outputs_spent) do
    outputs = Transaction.get_outputs(tx)

    input_amounts_by_currency = get_amounts_by_currency(outputs_spent)
    output_amounts_by_currency = get_amounts_by_currency(outputs)

    with :ok <- amounts_add_up?(input_amounts_by_currency, output_amounts_by_currency),
         do: {:ok, fees_paid(input_amounts_by_currency, output_amounts_by_currency)}
  end

  defp all_inputs_signed?(non_zero_inputs, sigs) do
    count_non_zero_signatures = Enum.count(sigs, &(&1 != @empty_signature))
    count_non_zero_inputs = length(non_zero_inputs)

    cond do
      count_non_zero_signatures > count_non_zero_inputs -> {:error, :superfluous_signature}
      count_non_zero_signatures < count_non_zero_inputs -> {:error, :missing_signature}
      true -> true
    end
  end

  defp fees_paid(input_amounts_by_currency, output_amounts_by_currency) do
    Enum.into(
      input_amounts_by_currency,
      %{},
      fn {input_currency, input_amount} ->
        # fee is implicit - it's the difference between funds owned and spend
        implicit_paid_fee = input_amount - Map.get(output_amounts_by_currency, input_currency, 0)

        {input_currency, implicit_paid_fee}
      end
    )
  end

  defp get_amounts_by_currency(outputs) do
    outputs
    |> Enum.group_by(fn %{currency: currency} -> currency end, fn %{amount: amount} -> amount end)
    |> Enum.map(fn {currency, amounts} -> {currency, Enum.sum(amounts)} end)
    |> Map.new()
  end

  defp amounts_add_up?(input_amounts, output_amounts) do
    for {output_currency, output_amount} <- Map.to_list(output_amounts) do
      input_amount = Map.get(input_amounts, output_currency, 0)
      input_amount >= output_amount
    end
    |> Enum.all?()
    |> if(do: :ok, else: {:error, :amounts_do_not_add_up})
  end
end
