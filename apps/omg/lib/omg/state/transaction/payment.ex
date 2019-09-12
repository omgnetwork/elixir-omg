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
      Internal representation of a payment transaction done on Plasma chain.

      This module holds the representation of a "raw" transaction, i.e. without signatures nor recovered input spenders
  """
  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Transaction
  require Utxo

  @zero_address OMG.Eth.zero_address()
  @zero_metadata <<0::256>>

  defstruct [:inputs, :outputs, metadata: @zero_metadata]

  @type t() :: %__MODULE__{
          inputs: list(input()),
          outputs: list(output()),
          metadata: Transaction.metadata()
        }

  @type input() :: %{
          blknum: non_neg_integer(),
          txindex: non_neg_integer(),
          oindex: non_neg_integer()
        }

  @type output() :: %{
          owner: Crypto.address_t(),
          currency: currency(),
          amount: non_neg_integer()
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
  Creates a new transaction from a list of inputs and a list of outputs.
  Adds empty (zeroes) inputs and/or outputs to reach the expected size
  of `@max_inputs` inputs and `@max_outputs` outputs.

  assumptions:
  ```
    length(inputs) <= @max_inputs
    length(outputs) <= @max_outputs
  ```
  """
  @spec new(
          list({pos_integer, pos_integer, 0..3}),
          list({Crypto.address_t(), currency(), pos_integer}),
          Transaction.metadata()
        ) :: t()
  def new(inputs, outputs, metadata \\ @zero_metadata)

  def new(inputs, outputs, metadata)
      when Transaction.is_metadata(metadata) and length(inputs) <= @max_inputs and length(outputs) <= @max_outputs do
    inputs =
      inputs
      |> Enum.map(fn {blknum, txindex, oindex} -> %{blknum: blknum, txindex: txindex, oindex: oindex} end)

    inputs = inputs ++ List.duplicate(%{blknum: 0, txindex: 0, oindex: 0}, @max_inputs - Kernel.length(inputs))

    outputs =
      outputs
      |> Enum.map(fn {owner, currency, amount} -> %{owner: owner, currency: currency, amount: amount} end)

    outputs =
      outputs ++
        List.duplicate(
          %{owner: @zero_address, currency: @zero_address, amount: 0},
          @max_outputs - Kernel.length(outputs)
        )

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

  defp reconstruct_inputs(inputs_rlp) do
    inputs_rlp
    |> Enum.map(&from_new_rlp_input/1)
    |> inputs_without_gaps()
  rescue
    _ -> {:error, :malformed_inputs}
  end

  # messy, see comments on the abstract output/input fixing this properly
  defp from_new_rlp_input(binary_input) when is_binary(binary_input) do
    binary_input
    |> :binary.decode_unsigned(:big)
    |> case do
      0 ->
        %{blknum: 0, txindex: 0, oindex: 0}

      encoded ->
        Utxo.position(blknum, txindex, oindex) = Utxo.Position.decode!(encoded)
        %{blknum: blknum, txindex: txindex, oindex: oindex}
    end
  end

  defp reconstruct_outputs(outputs_rlp) do
    outputs =
      Enum.map(outputs_rlp, fn [owner, currency, amount] ->
        with {:ok, cur12} <- parse_address(currency),
             {:ok, owner} <- parse_address(owner) do
          %{owner: owner, currency: cur12, amount: parse_int(amount)}
        end
      end)

    if(error = Enum.find(outputs, &match?({:error, _}, &1)),
      do: error,
      else: outputs
    )
    |> outputs_without_gaps()
  rescue
    _ -> {:error, :malformed_outputs}
  end

  defp reconstruct_metadata([]), do: {:ok, @zero_metadata}
  defp reconstruct_metadata([metadata]) when Transaction.is_metadata(metadata), do: {:ok, metadata}
  defp reconstruct_metadata([_]), do: {:error, :malformed_metadata}

  defp parse_int(binary), do: :binary.decode_unsigned(binary, :big)

  # necessary, because RLP handles empty string equally to integer 0
  @spec parse_address(<<>> | Crypto.address_t()) :: {:ok, Crypto.address_t()} | {:error, :malformed_address}
  defp parse_address(binary)
  defp parse_address(""), do: {:ok, <<0::160>>}
  defp parse_address(<<_::160>> = address_bytes), do: {:ok, address_bytes}
  defp parse_address(_), do: {:error, :malformed_address}

  defp inputs_without_gaps(inputs),
    do: check_for_gaps(inputs, %{blknum: 0, txindex: 0, oindex: 0}, {:error, :inputs_contain_gaps})

  defp outputs_without_gaps({:error, _} = error), do: error

  defp outputs_without_gaps(outputs),
    do:
      check_for_gaps(
        outputs,
        %{owner: @zero_address, currency: @zero_address, amount: 0},
        {:error, :outputs_contain_gaps}
      )

  # Check if any consecutive pair of elements contains empty followed by non-empty element
  # which means there is a gap
  defp check_for_gaps(items, empty, error) do
    items
    # discard - discards last unpaired element from a comparison
    |> Stream.chunk_every(2, 1, :discard)
    |> Enum.any?(fn
      [^empty, elt] when elt != empty -> true
      _ -> false
    end)
    |> if(do: error, else: {:ok, items})
  end
end

defimpl OMG.State.Transaction.Protocol, for: OMG.State.Transaction.Payment do
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Transaction
  require Utxo
  require Transaction.Payment

  @zero_address OMG.Eth.zero_address()
  @empty_signature <<0::size(520)>>

  # TODO: note this is fixed and improved in the abstract outputs/inputs PR
  @payment_marker Transaction.Markers.payment()

  @doc """
  Turns a structure instance into a structure of RLP items, ready to be RLP encoded, for a raw transaction
  """
  def get_data_for_rlp(%Transaction.Payment{inputs: inputs, outputs: outputs, metadata: metadata})
      when Transaction.is_metadata(metadata),
      do:
        [
          @payment_marker,
          # contract expects 4 inputs and outputs
          # TODO: this is ugly and messy, but will all get straightened out at the abstract ins/outs PR on hold
          inputs
          |> Kernel.++(List.duplicate(%{blknum: 0, txindex: 0, oindex: 0}, 4 - length(inputs)))
          |> Enum.map(&to_new_rlp_input/1),
          outputs
          |> Enum.map(fn %{owner: owner, currency: currency, amount: amount} -> [owner, currency, amount] end)
          |> Kernel.++(List.duplicate([@zero_address, @zero_address, 0], 4 - length(outputs)))
        ] ++ if(metadata, do: [metadata], else: [])

  def get_outputs(%Transaction.Payment{outputs: outputs}) do
    outputs
    |> Enum.reject(&match?(%{owner: @zero_address, currency: @zero_address, amount: 0}, &1))
  end

  def get_inputs(%Transaction.Payment{inputs: inputs}) do
    inputs
    |> Enum.map(fn %{blknum: blknum, txindex: txindex, oindex: oindex} -> Utxo.position(blknum, txindex, oindex) end)
    |> Enum.filter(&Utxo.Position.non_zero?/1)
  end

  defp to_new_rlp_input(%{blknum: blknum, txindex: txindex, oindex: oindex}),
    do: Utxo.position(blknum, txindex, oindex) |> Utxo.Position.encode() |> :binary.encode_unsigned(:big)

  @doc """
  True if the witnessses provided follow some extra custom validation.

  Currently this covers the requirement for all the inputs to be signed on predetermined positions
  """
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
  @spec can_apply?(Transaction.Payment.t(), list(Utxo.t())) :: {:ok, map()} | {:error, :amounts_do_not_add_up}
  def can_apply?(%Transaction.Payment{} = tx, input_utxos) do
    outputs = Transaction.get_outputs(tx)

    input_amounts_by_currency = get_amounts_by_currency(input_utxos)
    output_amounts_by_currency = get_amounts_by_currency(outputs)

    with :ok <- amounts_add_up?(input_amounts_by_currency, output_amounts_by_currency),
         do: {:ok, fees_paid(input_amounts_by_currency, output_amounts_by_currency)}
  end

  @doc """
  Effects of a payment transaction - spends all inputs and creates all outputs
  """
  def get_effects(%Transaction.Payment{} = tx, blknum, tx_index) do
    new_utxos_map = tx |> non_zero_utxos_from(blknum, tx_index) |> Map.new()
    spent_input_pointers = Transaction.get_inputs(tx)
    {spent_input_pointers, new_utxos_map}
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

  defp non_zero_utxos_from(tx, blknum, tx_index) do
    tx
    |> utxos_from(blknum, tx_index)
    |> Enum.filter(fn {_key, value} -> is_non_zero_amount?(value) end)
  end

  defp utxos_from(tx, blknum, tx_index) do
    hash = Transaction.raw_txhash(tx)

    tx
    |> Transaction.get_outputs()
    |> Enum.with_index()
    |> Enum.map(fn {%{owner: owner, currency: currency, amount: amount}, oindex} ->
      {Utxo.position(blknum, tx_index, oindex),
       %Utxo{owner: owner, currency: currency, amount: amount, creating_txhash: hash}}
    end)
  end

  defp is_non_zero_amount?(%{amount: 0}), do: false
  defp is_non_zero_amount?(%{amount: _}), do: true

  defp fees_paid(input_amounts_by_currency, output_amounts_by_currency) do
    input_amounts_by_currency
    |> Enum.into(%{}, fn {input_currency, input_amount} ->
      # fee is implicit - it's the difference between funds owned and spend
      implicit_paid_fee = input_amount - Map.get(output_amounts_by_currency, input_currency, 0)
      {input_currency, implicit_paid_fee}
    end)
  end

  defp get_amounts_by_currency(utxos) do
    utxos
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
