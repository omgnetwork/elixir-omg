defmodule OmiseGO.API.TestHelper do
  @moduledoc """
  Various shared functions used in API tests
  """

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Core

  import ExUnit.Assertions

  def generate_entity do
      {:ok, priv} = Crypto.generate_private_key
      {:ok, pub} = Crypto.generate_public_key(priv)
      {:ok, addr} = Crypto.generate_address(pub)
      %{priv: priv, addr: addr}
  end

  def signed(%Transaction{} = tx, priv1, priv2) do
    encoded_tx = tx |> Transaction.encode
    signature1 = Crypto.signature(encoded_tx, priv1)
    signature2 = Crypto.signature(encoded_tx, priv2)

    %Transaction.Signed{raw_tx: tx, sig1: signature1, sig2: signature2}
      |>Transaction.Signed.hash
  end

  def do_deposit(state, owner, amount) do
    {_, _, new_state} = Core.deposit(owner, amount, state)
    new_state
  end

  def success?(result) do
    assert {:ok, state} = result
    state
  end

  def fail?(result, expected_error) do
    assert {{:error, ^expected_error}, state} = result
    state
  end

  def same?({{:error, _someerror}, state}, expected_state) do
    assert expected_state == state
    state
  end

  def same?(state, expected_state) do
    assert expected_state == state
    state
  end

end
