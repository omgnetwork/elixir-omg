defmodule OMG.Eth.Config do
  alias OMG.Eth
  alias OMG.Eth.Encoding

  @doc """
  Gets a particular contract's address (by name) from somewhere
  `maybe_fetch_addr!(%{}, name)` will `Application.fetch_env!`, get the correct entry and decode
  Otherwise it just returns the entry from whatever the map provided, assuming it's decoded already
  """
  @spec maybe_fetch_addr!(%{atom => Eth.address()}, atom) :: Eth.address()
  def maybe_fetch_addr!(contract, name) do
    contract[name] || Encoding.from_hex(Application.fetch_env!(:omg_eth, :contract_addr)[name])
  end
end
