# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.State.Transaction do
  @moduledoc """
  Internal representation of transaction spent on Plasma chain
  """

  alias OMG.API.Crypto
  alias OMG.API.Utxo

  require Utxo

  @zero_address OMG.Eth.zero_address()
  @max_inputs 4
  @max_outputs 4

  @default_metadata nil

  defstruct [:inputs, :outputs, metadata: @default_metadata]

  @type t() :: %__MODULE__{
          inputs: list(input()),
          outputs: list(output()),
          metadata: binary() | nil
        }

  @type currency() :: Crypto.address_t()

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

  defmacro is_metadata(metadata) do
    quote do
      unquote(metadata) == nil or (is_binary(unquote(metadata)) and byte_size(unquote(metadata)) == 32)
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
          list({pos_integer, pos_integer, 0 | 1}),
          list({Crypto.address_t(), currency(), pos_integer}),
          binary() | nil
        ) :: t()
  def new(inputs, outputs, metadata \\ @default_metadata) when is_metadata(metadata) do
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

  def account_address?(@zero_address), do: false
  def account_address?(address) when is_binary(address) and byte_size(address) == 20, do: true
  def account_address?(_), do: false

  def reconstruct([inputs_rlp, outputs_rlp | rest_rlp])
      when rest_rlp == [] or (is_metadata(hd(rest_rlp)) and length(rest_rlp) == 1) do
    inputs =
      Enum.map(inputs_rlp, fn [blknum, txindex, oindex] ->
        %{blknum: parse_int(blknum), txindex: parse_int(txindex), oindex: parse_int(oindex)}
      end)

    outputs =
      Enum.map(outputs_rlp, fn [owner, currency, amount] ->
        with {:ok, cur12} <- parse_address(currency),
             {:ok, owner} <- parse_address(owner) do
          %{owner: owner, currency: cur12, amount: parse_int(amount)}
        end
      end)

    if error = Enum.find(outputs, &match?({:error, _}, &1)),
      do: error,
      else: {:ok, %__MODULE__{inputs: inputs, outputs: outputs, metadata: reconstruct_metadata(rest_rlp)}}
  end

  def reconstruct(_), do: {:error, :malformed_transaction}

  def reconstruct_metadata([]), do: nil
  def reconstruct_metadata([metadata]) when is_metadata(metadata), do: metadata

  defp parse_int(binary), do: :binary.decode_unsigned(binary, :big)

  # necessary, because RLP handles empty string equally to integer 0
  @spec parse_address(<<>> | Crypto.address_t()) :: {:ok, Crypto.address_t()} | {:error, :malformed_address}
  defp parse_address(binary)
  defp parse_address(""), do: {:ok, <<0::160>>}
  defp parse_address(<<_::160>> = address_bytes), do: {:ok, address_bytes}
  defp parse_address(_), do: {:error, :malformed_address}

  def decode(tx_bytes) do
    with {:ok, raw_tx_rlp_decoded_chunks} <- try_exrlp_decode(tx_bytes),
         do: reconstruct(raw_tx_rlp_decoded_chunks)
  end

  defp try_exrlp_decode(tx_bytes) do
    {:ok, ExRLP.decode(tx_bytes)}
  rescue
    _ -> {:error, :malformed_transaction_rlp}
  end

  def encode(transaction) do
    get_data_for_rlp(transaction)
    |> ExRLP.encode()
  end

  def get_data_for_rlp(%__MODULE__{inputs: inputs, outputs: outputs, metadata: metadata}) when is_metadata(metadata),
    do:
      [
        # contract expects 4 inputs and outputs
        Enum.map(inputs, fn %{blknum: blknum, txindex: txindex, oindex: oindex} -> [blknum, txindex, oindex] end) ++
          List.duplicate([0, 0, 0], 4 - length(inputs)),
        Enum.map(outputs, fn %{owner: owner, currency: currency, amount: amount} -> [owner, currency, amount] end) ++
          List.duplicate([@zero_address, @zero_address, 0], 4 - length(outputs))
      ] ++ if(metadata, do: [metadata], else: [])

  def hash(%__MODULE__{} = tx) do
    tx
    |> encode
    |> Crypto.hash()
  end

  @doc """
  Returns all input currencies
  """
  @spec get_currencies(t()) :: list(currency())
  def get_currencies(%__MODULE__{outputs: outputs}) do
    outputs
    |> Enum.map(& &1.currency)
  end

  @doc """
  Returns all inputs
  """
  def get_inputs(%__MODULE__{inputs: inputs}) do
    inputs
    |> Enum.map(fn %{blknum: blknum, txindex: txindex, oindex: oindex} -> Utxo.position(blknum, txindex, oindex) end)
  end

  @doc """
  Returns all outputs
  """
  @spec get_outputs(t()) :: list(output())
  def get_outputs(%__MODULE__{outputs: outputs}), do: outputs
end
