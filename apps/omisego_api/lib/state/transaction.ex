defmodule OmiseGO.API.State.Transaction do
  @moduledoc """
  Internal representation of a spend transaction on Plasma chain
  """

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Transaction.Signed

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
  Creates transaction from utxos where first output belongs to receiver and second belongs to owner of utxos
  and the amount decreased by receiver's amount and the fee.

  assumptions:
   length(utxos) = 1 | 2
  """
  @spec create_from_utxos(
          %{address: Crypto.address_t(), utxos: map()},
          %{address: Crypto.address_t(), amount: pos_integer()},
          fee :: non_neg_integer()
        ) :: {:ok, t()} | {:error, atom()}
  def create_from_utxos(sender_utxos, receiver, fee \\ 0)
  def create_from_utxos(_utxos, _receiver, fee) when fee < 0, do: {:error, :invalid_fee}
  def create_from_utxos(%{utxos: utxos}, _, _) when length(utxos) > @max_inputs, do: {:error, :too_many_utxo}

  def create_from_utxos(%{utxos: utxos} = inputs, receiver, fee) do
    with {:ok, currency} <- validate_currency(utxos) do
      do_create_from_utxos(inputs, currency, receiver, fee)
    end
  end

  defp do_create_from_utxos(
         %{address: sender_address, utxos: utxos},
         currency,
         %{address: receiver_address, amount: amount},
         fee
       ) do
    total_amount =
      utxos
      |> Enum.map(&Map.fetch!(&1, :amount))
      |> Enum.sum()

    inputs =
      utxos
      |> Enum.map(fn %{blknum: blknum, txindex: txindex, oindex: oindex} ->
        {blknum, txindex, oindex}
      end)

    amount2 = total_amount - amount - fee

    outputs = [
      {receiver_address, amount},
      {sender_address, amount2}
    ]

    with :ok <- validate_amount(amount),
         :ok <- validate_amount(amount2),
         do: {:ok, new(inputs, currency, outputs)}
  end

  defp validate_currency([%{currency: cur1}, %{currency: cur2}]) when cur1 != cur2,
    do: {:error, :currency_mixing_not_possible}

  defp validate_currency([%{currency: cur1} | _]), do: {:ok, cur1}

  defp validate_amount(output_amount) when output_amount < 0, do: {:error, :amount_negative_value}
  defp validate_amount(output_amount) when is_integer(output_amount), do: :ok

  @doc """
   assumptions:
     length(inputs) <= 2
     length(outputs) <= 2
   behavior:
      Adds empty (zeroes) inputs and/or outputs to reach the expected size
      of 2 inputs and 2 outputs.
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
    private keys are in the form: <<54, 43, 207, 67, 140, 160, 190, 135, 18, 162, 70, 120, 36, 245, 106, 165, 5, 101, 183,
      55, 11, 117, 126, 135, 49, 50, 12, 228, 173, 219, 183, 175>>
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
