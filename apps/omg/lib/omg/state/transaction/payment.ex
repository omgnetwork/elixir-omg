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

defmodule OMG.State.Transaction.Payment do
  @moduledoc """
  Internal representation of a raw payment transaction done on Plasma chain.

  This module holds the representation of a "raw" transaction, i.e. without signatures nor recovered input spenders
  """
  alias OMG.Crypto
  alias OMG.Output
  alias OMG.State.Transaction

  require Transaction

  @zero_metadata <<0::256>>

  defstruct [:inputs, :outputs, metadata: @zero_metadata]

  @type t() :: %__MODULE__{
          inputs: list(tuple()),
          outputs: list(Output.FungibleMoreVPToken.t()),
          metadata: Transaction.metadata()
        }

  @type currency() :: Crypto.address_t()

  @max_inputs 4
  @max_outputs 4

  defmacro max_inputs do
    quote do
      unquote(@max_inputs)
    end
  end

  defmacro max_outputs do
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
    %__MODULE__{inputs: inputs, outputs: outputs, metadata: metadata}
  end

  @doc """
  Transaform the structure of RLP items after a successful RLP decode of a raw transaction, into a structure instance
  """
  def reconstruct([inputs_rlp, outputs_rlp | rest_rlp])
      when rest_rlp == [] or length(rest_rlp) == 1 do
    with {:ok, inputs} <- reconstruct_inputs(inputs_rlp),
         {:ok, outputs} <- reconstruct_outputs(outputs_rlp),
         {:ok, metadata} <- reconstruct_metadata(rest_rlp),
         do: {:ok, %__MODULE__{inputs: inputs, outputs: outputs, metadata: metadata}}
  end

  def reconstruct(_), do: {:error, :malformed_transaction}

  # `new_input/1` and `new_output/1` are here to just help interpret the short-hand form of inputs outputs when doing
  # `new/3`
  defp new_input({blknum, txindex, oindex}), do: %OMG.InputPointer{blknum: blknum, txindex: txindex, oindex: oindex}

  defp new_output({owner, currency, amount}),
    do: %Output.FungibleMoreVPToken{owner: owner, currency: currency, amount: amount}

  defp reconstruct_inputs(inputs_rlp) do
    with {:ok, inputs} <- parse_inputs(inputs_rlp),
         do: {:ok, inputs}
  end

  defp reconstruct_outputs([]), do: {:error, :empty_outputs}

  defp reconstruct_outputs(outputs_rlp) do
    with {:ok, outputs} <- parse_outputs(outputs_rlp),
         do: {:ok, outputs}
  end

  defp reconstruct_metadata([]), do: {:ok, @zero_metadata}
  defp reconstruct_metadata([metadata]) when Transaction.is_metadata(metadata), do: {:ok, metadata}
  defp reconstruct_metadata([_]), do: {:error, :malformed_metadata}

  defp parse_inputs(inputs_rlp) do
    {:ok, Enum.map(inputs_rlp, &parse_input!/1)}
  rescue
    _ -> {:error, :malformed_inputs}
  end

  defp parse_outputs(outputs_rlp) do
    outputs = Enum.map(outputs_rlp, &Output.dispatching_reconstruct/1)

    with nil <- Enum.find(outputs, &match?({:error, _}, &1)),
         true <- only_allowed_output_types?(outputs) || {:error, :tx_cannot_create_output_type},
         do: {:ok, outputs}
  rescue
    _ -> {:error, :malformed_outputs}
  end

  defp only_allowed_output_types?(outputs),
    do: Enum.all?(outputs, &match?(%Output.FungibleMoreVPToken{}, &1))

  # NOTE: we predetermine the input_pointer type, this is most likely not generic enough - rethink
  #       most likely one needs to route through generic InputPointer` function that does the dispatch
  defp parse_input!(input_pointer) do
    {:ok, utxo_pos_tuple} = OMG.InputPointer.decode(input_pointer)
    utxo_pos_tuple
  end
end

defimpl OMG.State.Transaction.Protocol, for: OMG.State.Transaction.Payment do
  alias OMG.Output
  alias OMG.State.Transaction

  require Transaction

  @empty_signature <<0::size(520)>>

  # TODO: dry wrt. Application.fetch_env!(:omg, :tx_types_modules)? Use `bimap` perhaps?
  @payment_marker <<1>>

  @doc """
  Turns a structure instance into a structure of RLP items, ready to be RLP encoded, for a raw transaction
  """
  @spec get_data_for_rlp(Transaction.Payment.t()) :: list(any())
  def get_data_for_rlp(%Transaction.Payment{inputs: inputs, outputs: outputs, metadata: metadata})
      when Transaction.is_metadata(metadata),
      do: [
        @payment_marker,
        Enum.map(inputs, &OMG.InputPointer.get_data_for_rlp/1),
        Enum.map(outputs, &OMG.Output.get_data_for_rlp/1),
        # used to be optional and as such was `if`-appended if not null here
        # When it is not optional, and there's the if, dialyzer complains about the if
        metadata
      ]

  @spec get_outputs(Transaction.Payment.t()) :: list(OMG.Output.FungibleMoreVPToken.t())
  def get_outputs(%Transaction.Payment{outputs: outputs}), do: outputs

  @spec get_inputs(Transaction.Payment.t()) :: list(tuple())
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
  @spec can_apply?(Transaction.Payment.t(), list(OMG.Output.FungibleMoreVPToken.t())) ::
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
    input_amounts_by_currency
    |> Enum.into(%{}, fn {input_currency, input_amount} ->
      # fee is implicit - it's the difference between funds owned and spend
      implicit_paid_fee = input_amount - Map.get(output_amounts_by_currency, input_currency, 0)
      {input_currency, implicit_paid_fee}
    end)
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
