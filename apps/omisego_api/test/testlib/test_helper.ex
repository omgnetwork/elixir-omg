defmodule OmiseGO.API.TestHelper do
  @moduledoc """
  Various shared functions used in API tests
  """

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Core

  def generate_entity do
      {:ok, priv} = Crypto.generate_private_key
      {:ok, pub} = Crypto.generate_public_key(priv)
      {:ok, addr} = Crypto.generate_address(pub)
      %{priv: priv, addr: addr}
  end

  def do_deposit(state, owner, amount) do
    {_, _, new_state} = Core.deposit(owner, amount, state)
    new_state
  end

end
