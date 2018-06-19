defmodule OmiseGO.API.TestHelper do
  @moduledoc """
  Various shared functions used in API tests
  """

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.Transaction

  def generate_entity do
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, addr} = Crypto.generate_address(pub)
    %{priv: priv, addr: addr}
  end

  def do_deposit(state, owner, %{amount: amount, currency: cur, blknum: blknum}) do
    {_, _, new_state} = Core.deposit([%{owner: owner.addr, currency: cur, amount: amount, blknum: blknum}], state)

    new_state
  end

  @doc """
  convenience function around Transaction.new to create recovered transactions,
  by allowing to provider private keys of utxo owners along with the inputs
  """
  @spec create_recovered(
          list({pos_integer, pos_integer, 0 | 1, map}),
          Transaction.currency(),
          list({Crypto.address_t(), pos_integer})
        ) :: Transaction.Recovered.t()
  def create_recovered(inputs, currency, outputs) do
    {signed_tx, _raw_tx} = create_signed(inputs, currency, outputs)
    {:ok, recovered} = Transaction.Recovered.recover_from(signed_tx)
    recovered
  end

  @doc """
  convenience function around Transaction.new to create signed transactions (see create_recovered)
  """
  @spec create_signed(
          list({pos_integer, pos_integer, 0 | 1, map}),
          Transaction.currency(),
          list({Crypto.address_t(), pos_integer})
        ) :: {Transaction.Signed.t(), Transaction.t()}
  def create_signed(inputs, currency, outputs) do
    raw_tx =
      Transaction.new(
        inputs |> Enum.map(fn {blknum, txindex, oindex, _} -> {blknum, txindex, oindex} end),
        currency,
        outputs |> Enum.map(fn {newowner, amout} -> {newowner.addr, amout} end)
      )

    [priv1, priv2 | _] = inputs |> Enum.map(fn {_, _, _, owner} -> owner.priv end) |> Enum.concat([<<>>, <<>>])

    {Transaction.sign(raw_tx, priv1, priv2), raw_tx}
  end
end
