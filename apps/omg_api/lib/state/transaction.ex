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

  @zero_address Crypto.zero_address()
  @max_inputs 2

  defstruct [
    :blknum1,
    :txindex1,
    :oindex1,
    :blknum2,
    :txindex2,
    :oindex2,
    :cur12,
    :newowner1,
    :amount1,
    :newowner2,
    :amount2
  ]

  @type t() :: %__MODULE__{
          blknum1: non_neg_integer(),
          txindex1: non_neg_integer(),
          oindex1: 0 | 1,
          blknum2: non_neg_integer(),
          txindex2: non_neg_integer(),
          oindex2: 0 | 1,
          cur12: currency(),
          newowner1: Crypto.address_t(),
          amount1: pos_integer(),
          newowner2: Crypto.address_t(),
          amount2: non_neg_integer()
        }

  @type currency :: Crypto.address_t()

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
              oindex: 0 | 1,
              currency: Crypto.address_t(),
              amount: pos_integer()
            }
          ],
          [%{owner: Crypto.address_t(), amount: non_neg_integer()}],
          non_neg_integer()
        ) :: {:ok, t()} | {:error, atom()}
  def create_from_utxos(inputs, outputs, fee)
  def create_from_utxos(inputs, _, _) when not is_list(inputs), do: {:error, :inputs_should_be_list}
  def create_from_utxos(_, outputs, _) when not is_list(outputs), do: {:error, :outputs_should_be_list}
  def create_from_utxos(inputs, _, _) when length(inputs) > @max_inputs, do: {:error, :too_many_inputs}
  def create_from_utxos([], _, _), do: {:error, :at_least_one_input_required}
  def create_from_utxos(_, outputs, _) when length(outputs) > @max_inputs, do: {:error, :too_many_outputs}
  def create_from_utxos(_, _, fee) when fee < 0, do: {:error, :invalid_fee}

  def create_from_utxos(inputs, outputs, fee) do
    with {:ok, currency} <- validate_currency(inputs),
         :ok <- validate_amount(inputs),
         :ok <- validate_amount(outputs),
         :ok <- amounts_add_up?(inputs, outputs, fee) do
      {
        :ok,
        new(
          inputs |> Enum.map(&{&1.blknum, &1.txindex, &1.oindex}),
          currency,
          outputs |> Enum.map(&{&1.owner, &1.amount})
        )
      }
    end
  end

  defp validate_currency(inputs) do
    currencies =
      inputs
      |> Enum.map(& &1.currency)
      |> Enum.uniq()

    if match?([_], currencies),
      do: {:ok, currencies |> hd()},
      else: {:error, :currency_mixing_not_possible}
  end

  # Validates amount in both inputs and outputs
  defp validate_amount(items) do
    all_valid? =
      items
      |> Enum.map(& &1.amount)
      |> Enum.all?(fn amount -> is_integer(amount) and amount >= 0 end)

    if all_valid?,
      do: :ok,
      else: {:error, :amount_noninteger_or_negative}
  end

  defp amounts_add_up?(inputs, outputs, fee) do
    spent =
      inputs
      |> Enum.map(& &1.amount)
      |> Enum.sum()

    received =
      outputs
      |> Enum.map(& &1.amount)
      |> Enum.sum()

    cond do
      spent < received ->
        {:error, :not_enough_funds_to_cover_spend}

      spent < received + fee ->
        {:error, :not_enough_funds_to_cover_fee}

      true ->
        :ok
    end
  end

  @doc """
  Adds empty (zeroes) inputs and/or outputs to reach the expected size
  of 2 inputs and 2 outputs.

  assumptions:
  ```
    length(inputs) <= 2
    length(outputs) <= 2
  ```
  """
  @spec new(
          list({pos_integer, pos_integer, 0 | 1}),
          Crypto.address_t(),
          list({Crypto.address_t(), pos_integer})
        ) :: t()
  def new(inputs, currency, outputs) do
    inputs = inputs ++ List.duplicate({0, 0, 0}, @max_inputs - Kernel.length(inputs))
    outputs = outputs ++ List.duplicate({@zero_address, 0}, @max_inputs - Kernel.length(outputs))

    inputs =
      inputs
      |> Enum.with_index(1)
      |> Enum.map(fn {{blknum, txindex, oindex}, index} ->
        %{
          String.to_existing_atom("blknum#{index}") => blknum,
          String.to_existing_atom("txindex#{index}") => txindex,
          String.to_existing_atom("oindex#{index}") => oindex
        }
      end)
      |> Enum.reduce(%{}, &Map.merge/2)

    outputs =
      outputs
      |> Enum.with_index(1)
      |> Enum.map(fn {{newowner, amount}, index} ->
        %{
          String.to_existing_atom("newowner#{index}") => newowner,
          String.to_existing_atom("amount#{index}") => amount
        }
      end)
      |> Enum.reduce(%{cur12: currency}, &Map.merge/2)

    struct(__MODULE__, Map.merge(inputs, outputs))
  end

  def account_address?(@zero_address), do: false
  def account_address?(address) when is_binary(address) and byte_size(address) == 20, do: true
  def account_address?(_), do: false

  def encode(tx) do
    [
      tx.blknum1,
      tx.txindex1,
      tx.oindex1,
      tx.blknum2,
      tx.txindex2,
      tx.oindex2,
      tx.cur12,
      tx.newowner1,
      tx.amount1,
      tx.newowner2,
      tx.amount2
    ]
    |> ExRLP.encode()
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
  @spec sign(t(), Crypto.priv_key_t(), Crypto.priv_key_t()) :: Signed.t()
  def sign(%__MODULE__{} = tx, priv1, priv2) do
    encoded_tx = encode(tx)
    signature1 = signature(encoded_tx, priv1)
    signature2 = signature(encoded_tx, priv2)

    transaction = %Signed{raw_tx: tx, sig1: signature1, sig2: signature2}
    %{transaction | signed_tx_bytes: Signed.encode(transaction)}
  end

  defp signature(_encoded_tx, <<>>), do: <<0::size(520)>>
  defp signature(encoded_tx, priv), do: Crypto.signature(encoded_tx, priv)
end
