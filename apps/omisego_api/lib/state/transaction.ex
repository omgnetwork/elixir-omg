defmodule OmiseGO.API.State.Transaction do
  @moduledoc """
  Internal representation of a spend transaction on Plasma chain
  """

  alias OmiseGO.API.State.Transaction.{Signed}
  alias OmiseGO.API.Crypto

  @zero_address <<0::size(160)>>
  @number_of_transactions 2

  defstruct [
    :blknum1,
    :txindex1,
    :oindex1,
    :blknum2,
    :txindex2,
    :oindex2,
    :newowner1,
    :amount1,
    :newowner2,
    :amount2,
    :fee
  ]

  @type t() :: %__MODULE__{
          blknum1: pos_integer(),
          txindex1: pos_integer(),
          oindex1: pos_integer(),
          blknum2: pos_integer(),
          txindex2: pos_integer(),
          oindex2: pos_integer(),
          newowner1: pos_integer(),
          amount1: pos_integer(),
          newowner2: pos_integer(),
          amount2: pos_integer(),
          fee: pos_integer()
        }

  def create_from_utxos(%{utxos: utxos_ble}, _, _) when length(utxos_ble) > @number_of_transactions,
    do: {:error, :too_many_utxo}

  def create_from_utxos(
        %{address: change_address, utxos: utxos},
        %{address: receiver_address, amount: amount},
        fee
      ) do
    parts_transaction =
      utxos
      |> Enum.with_index(1)
      |> Enum.map(fn {utxo, number} ->
        %{
          String.to_existing_atom("blknum#{number}") => utxo.blknum,
          String.to_existing_atom("txindex#{number}") => utxo.txindex,
          String.to_existing_atom("oindex#{number}") => utxo.oindex,
          amount: utxo.amount
        }
      end)

    all_amount = Enum.reduce(parts_transaction, 0, &(&1.amount + &2))

    transaction =
      Enum.reduce(parts_transaction, %{}, fn part_transaction, acc ->
        {_, part_transaction} = Map.pop(part_transaction, :amount)
        Map.merge(acc, part_transaction)
      end)

    transaction =
      struct!(
        __MODULE__,
        Map.merge(transaction, %{
          newowner1: receiver_address,
          amount1: amount,
          newowner2: change_address,
          amount2: all_amount - amount - fee,
          fee: fee
        })
      )

    case validate(transaction) do
      :ok -> {:ok, transaction}
      {:error, _} = error -> error
    end
  end

  defp validate(%__MODULE__{} = transaction) do
    cond do
      transaction.amount1 < 0 -> {:error, :amount_negative_value}
      transaction.amount2 < 0 -> {:error, :amount_negative_value}
      transaction.fee < 0 -> {:error, :fee_negative_value}
      true -> :ok
    end
  end

  @doc """
   assumptions:
     length(inputs) <= @number_of_transaction
     length(outputs) <= @number_of_transaction
   behavior:
      Adjusts the inputs and outputs for each transaction with empty ones
      to match the expected size of @number_of_transaction. Then adds the fee.
       for inputs add {0, 0, 0} where {blknum, txindex, oindex}
       for outpust add {0, 0} where {newowner, amount}
  """
  @spec new(
          list({pos_integer, pos_integer, 0 | 1}),
          list({<<_::256>>, pos_integer}),
          pos_integer
        ) :: __MODULE__.t()
  def new(inputs, outputs, fee) do
    inputs = inputs ++ List.duplicate({0, 0, 0}, @number_of_transactions - Kernel.length(inputs))
    outputs = outputs ++ List.duplicate({0, 0}, @number_of_transactions - Kernel.length(outputs))

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
      |> Enum.reduce(%{}, &Map.merge/2)

    struct(__MODULE__, Map.put(Map.merge(inputs, outputs), :fee, fee))
  end

  def zero_address, do: @zero_address

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
      tx.newowner1,
      tx.amount1,
      tx.newowner2,
      tx.amount2
    ]
    |> ExRLP.encode
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
  @spec sign(__MODULE__.t(), <<_::256>>, <<_::256>>) :: Signed.t()
  def sign(%__MODULE__{} = tx, priv1, priv2) do
    encoded_tx = encode(tx)
    signature1 = signature(encoded_tx, priv1)
    signature2 = signature(encoded_tx, priv2)

    %Signed{raw_tx: tx, sig1: signature1, sig2: signature2}
  end

  defp signature(_encoded_tx, <<>>), do: <<0::size(520)>>
  defp signature(encoded_tx, priv), do: Crypto.signature(encoded_tx, priv)
end
