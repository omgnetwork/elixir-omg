defmodule OmiseGO.API.TestHelper do
  @moduledoc """
  Various shared functions used in API tests
  """

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.Transaction

  def generate_entity do
    with {:ok, priv} = Crypto.generate_private_key()
      {:ok, pub} = Crypto.generate_public_key(priv)
      {:ok, addr} = Crypto.generate_address(pub) do
      %{priv: priv, addr: addr}
    end
  end

  def do_deposit(state, owner, %{amount: amount, blknum: blknum}) do
    {_, _, new_state} = Core.deposit([%{owner: owner.addr, amount: amount, blknum: blknum}], state)

    new_state
  end

  @doc """
  convenience function around Transaction.new to create recovered transactions,
  by allowing to provider private keys of utxo owners along with the inputs
  """
  @spec create_recovered(
          list({pos_integer, pos_integer, 0 | 1, map}),
          list({<<_::256>>, pos_integer}),
          pos_integer
        ) :: Transaction.Recovered.t()
  def create_recovered(inputs, outputs, fee \\ 0) do
    {signed_tx, _raw_tx} = create_signed(inputs, outputs, fee)
    {:ok, recovered} = Transaction.Recovered.recover_from(signed_tx)
    recovered
  end

  @doc """
  convenience function around Transaction.new to create signed transactions (see create_recovered)
  """
  @spec create_signed(
          list({pos_integer, pos_integer, 0 | 1, map}),
          list({<<_::256>>, pos_integer}),
          pos_integer
        ) :: {Transaction.Signed.t(), Transaction.t()}
  def create_signed(inputs, outputs, fee \\ 0) do
    raw_tx =
      Transaction.new(
        inputs |> Enum.map(fn {blknum, txindex, oindex, _} -> {blknum, txindex, oindex} end),
        outputs |> Enum.map(fn {newowner, amout} -> {newowner.addr, amout} end),
        fee
      )

    [priv1, priv2 | _] = inputs |> Enum.map(fn {_, _, _, owner} -> owner.priv end) |> Enum.concat([<<>>, <<>>])

    {Transaction.sign(raw_tx, priv1, priv2), raw_tx}
  end
end
