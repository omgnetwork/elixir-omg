defmodule OMG.Eth.RootChain.SubmitBlock do
  alias OMG.Eth
  alias OMG.Eth.RootChain

  @spec submit(binary(), pos_integer(), pos_integer(), RootChain.optional_addr_t(), RootChain.optional_addr_t()) ::
          {:error, binary() | atom() | map()}
          | {:ok, binary()}
  def submit(hash, nonce, gas_price, from, contract) do
    # NOTE: we're not using any defaults for opts here!
    Eth.contract_transact(
      from,
      contract,
      "submitBlock(bytes32)",
      [hash],
      nonce: nonce,
      gasPrice: gas_price,
      value: 0,
      gas: 100_000
    )
  end
end
