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

  def do_deposit(state, owner, %{amount: amount, block_height: block_height}) do
    {_, _, new_state} =
      Core.deposit([%{owner: owner.addr, amount: amount, block_height: block_height}], state)

    new_state
  end

  def create_recovered(inputs, outputs, fee \\ 0) do
    inputs = inputs |> Enum.map(fn
        %{} = elem -> elem
        {blknum, txindex, oindex, owner} -> %{blknum: blknum, txindex: txindex, oindex: oindex, owner: owner}
    end)
    outputs = outputs |> Enum.map(fn
        %{} = elem -> elem
        {newowner, amount} -> %{newowner: newowner, amount: amount}
    end)
    raw_tx =
      Transaction.new(
        inputs |> Enum.map(&Map.delete(&1, :owner)),
        outputs |> Enum.map(&%{&1 | newowner: &1.newowner.addr}),
        fee
      )

    [sig1, sig2 | _] =
      inputs |> Enum.map(fn %{owner: owner} -> owner.priv end) |> Enum.concat([<<>>, <<>>])

    Transaction.Recovered.recover_from(Transaction.sign(raw_tx, sig1, sig2))
  end
end
