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
  alias OMG.API.State.Transaction.Signed
  alias OMG.API.Utxo

  require Utxo

  @zero_address Crypto.zero_address()
  @max_inputs 4
  @max_outputs 4

  defstruct [:inputs, :outputs]

  @type t() :: %__MODULE__{
          inputs: list(input()),
          outputs: list(output())
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

  @doc """
  Creates transaction from utxo positions and outputs. Provides simple, stateless validation on arguments.

  #### Assumptions:
   * length of inputs between 1 and `@max_inputs`
   * length of outputs between 0 and `@max_inputs`
   * the same currency for each output
   * all amounts are non-negative integers
  """
  @spec create_from_utxos(
          [
            %{
              blknum: pos_integer(),
              txindex: non_neg_integer(),
              oindex: non_neg_integer(),
              currency: Crypto.address_t(),
              amount: pos_integer()
            }
          ],
          [%{owner: Crypto.address_t(), amount: non_neg_integer()}]
        ) :: {:ok, t()} | {:error, atom()}
  def create_from_utxos(inputs, outputs)
  def create_from_utxos(inputs, _) when not is_list(inputs), do: {:error, :inputs_should_be_list}
  def create_from_utxos(_, outputs) when not is_list(outputs), do: {:error, :outputs_should_be_list}
  def create_from_utxos(inputs, _) when length(inputs) > @max_inputs, do: {:error, :too_many_inputs}
  def create_from_utxos([], _), do: {:error, :at_least_one_input_required}
  def create_from_utxos(_, outputs) when length(outputs) > @max_outputs, do: {:error, :too_many_outputs}

  def create_from_utxos(input_utxos, outputs) do
    with {:ok, currency} <- validate_currency(input_utxos, outputs),
         :ok <- validate_amount(input_utxos),
         :ok <- validate_amount(outputs),
         :ok <- amounts_add_up?(input_utxos, outputs) do
      {:ok,
       new(
         input_utxos |> Enum.map(&{&1.blknum, &1.txindex, &1.oindex}),
         outputs |> Enum.map(&{&1.owner, currency, &1.amount})
       )}
    end
  end

  defp validate_currency(input_utxos, outputs) do
    currencies =
      (input_utxos ++ outputs)
      |> Enum.map(& &1.currency)
      |> Enum.dedup()

    # NOTE we support one currency
    case currencies do
      [_] -> {:ok, currencies |> hd()}
      [] -> {:ok, @zero_address}
      _ -> {:error, :currency_mixing_not_possible}
    end
  end

  # Validates amount in both inputs and outputs
  defp validate_amount(amounts) do
    all_valid? =
      amounts
      |> Enum.map(& &1.amount)
      |> Enum.all?(fn amount -> is_integer(amount) and amount >= 0 end)

    if all_valid?,
      do: :ok,
      else: {:error, :amount_noninteger_or_negative}
  end

  defp amounts_add_up?(inputs, outputs) do
    spent =
      inputs
      |> Enum.map(& &1.amount)
      |> Enum.sum()

    received =
      outputs
      |> Enum.map(& &1.amount)
      |> Enum.sum()

    if received > spent, do: {:error, :not_enough_funds_to_cover_spend}, else: :ok
  end

  @doc """
  Creates a new transaction from a list of inputs and a list of outputs.
  Adds empty (zeroes) inputs and/or outputs to reach the expected size
  of 4 inputs and 4 outputs.
  ```
  """
  @spec new(
          list({pos_integer, pos_integer, 0 | 1}),
          list({Crypto.address_t(), currency(), pos_integer})
        ) :: t()
  def new(inputs, outputs) do
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

    %__MODULE__{inputs: inputs, outputs: outputs}
  end

  def account_address?(@zero_address), do: false
  def account_address?(address) when is_binary(address) and byte_size(address) == 20, do: true
  def account_address?(_), do: false

  def from_rlp([inputs_rlp, outputs_rlp]) do
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
      else: {:ok, %__MODULE__{inputs: inputs, outputs: outputs}}
  end

  def from_rlp(_), do: {:error, :malformed_transaction}

  defp parse_int(binary), do: :binary.decode_unsigned(binary, :big)

  # necessary, because RLP handles empty string equally to integer 0
  @spec parse_address(<<>> | Crypto.address_t()) :: {:ok, Crypto.address_t()} | {:error, :malformed_address}
  defp parse_address(binary)
  defp parse_address(""), do: {:ok, <<0::160>>}
  defp parse_address(<<_::160>> = address_bytes), do: {:ok, address_bytes}
  defp parse_address(_), do: {:error, :malformed_address}

  def encode(transaction) do
    preper_to_exrlp(transaction)
    |> ExRLP.encode()
  end

  def preper_to_exrlp(%__MODULE__{inputs: inputs, outputs: outputs}),
    do: [
      # contract has fix size 4 inputs
      Enum.map(inputs, fn %{blknum: blknum, txindex: txindex, oindex: oindex} -> [blknum, txindex, oindex] end) ++
        List.duplicate([0, 0, 0], 4 - length(inputs)),
      # contract has fix size 4 outputs
      Enum.map(outputs, fn %{owner: owner, currency: currency, amount: amount} -> [owner, currency, amount] end) ++
        List.duplicate([@zero_address, @zero_address, 0], 4 - length(outputs))
    ]

  def decode(tx_bytes) do
    try do
      ExRLP.decode(tx_bytes) |> from_rlp()
    rescue
      _ -> {:error, :malformed_transaction_rlp}
    end
  end

  def hash(%__MODULE__{} = tx) do
    tx
    |> encode
    |> Crypto.hash()
  end

  @doc """
    Signs transaction using private keys

    private keys are in the  binary form, e.g.:
    ```<<54, 43, 207, 67, 140, 160, 190, 135, 18, 162, 70, 120, 36, 245, 106, 165, 5, 101, 183,
      55, 11, 117, 126, 135, 49, 50, 12, 228, 173, 219, 183, 175>>```
  """
  @spec sign(t(), list(Crypto.priv_key_t())) :: Signed.t()
  def sign(%__MODULE__{} = tx, private_keys) do
    encoded_tx = encode(tx)
    sigs = Enum.map(private_keys, fn pk -> signature(encoded_tx, pk) end)

    transaction = %Signed{raw_tx: tx, sigs: sigs}
    %{transaction | signed_tx_bytes: Signed.encode(transaction)}
  end

  defp signature(_encoded_tx, <<>>), do: <<0::size(520)>>
  defp signature(encoded_tx, priv), do: Crypto.signature(encoded_tx, priv)

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
