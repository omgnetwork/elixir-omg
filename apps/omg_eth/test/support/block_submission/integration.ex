defmodule OMG.Eth.Support.BlockSubmission.Integration do
  @moduledoc """
  Interface to contract block submission.
  """
  alias OMG.Eth.Configuration
  alias OMG.Eth.Encoding

  @type address :: <<_::160>>
  @type hash :: <<_::256>>

  @doc """
  Send transaction to be singed by a key managed by Ethereum node, geth or parity.
  For geth, account must be unlocked externally.
  If using parity, account passphrase must be provided directly or via config.
  """
  @spec send(binary()) :: {:ok, OMG.Eth.hash()} | {:error, any()}
  @spec send(map()) :: {:ok, OMG.Eth.hash()} | {:error, any()}
  def send(txmap) do
    eth_send_transaction = Ethereumex.HttpClient.eth_send_transaction(txmap)

    case eth_send_transaction do
      {:ok, receipt_enc} -> {:ok, Encoding.from_hex(receipt_enc)}
      other -> other
    end
  end

  @spec submit_block(binary(), pos_integer(), pos_integer()) ::
          {:error, binary() | atom() | map()} | {:ok, <<_::256>>}
  def submit_block(hash, nonce, gas_price) do
    contract = Encoding.from_hex(Configuration.contracts().plasma_framework, :mixed)
    from = Encoding.from_hex(Configuration.authority_address(), :mixed)
    submit(hash, nonce, gas_price, from, contract)
  end

  @spec submit(
          binary(),
          pos_integer(),
          pos_integer(),
          OMG.Eth.address(),
          OMG.Eth.address()
        ) ::
          {:error, binary() | atom() | map()}
          | {:ok, <<_::256>>}
  def submit(hash, nonce, gas_price, from, contract) do
    # NOTE: we're not using any defaults for opts here!
    contract_transact(
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

  defp contract_transact(from, to, signature, args, opts) do
    data = encode_tx_data(signature, args)

    txmap =
      %{from: Encoding.to_hex(from), to: Encoding.to_hex(to), data: data}
      |> Map.merge(Map.new(opts))
      |> encode_all_integer_opts()

    send(txmap)
  end

  defp encode_tx_data(signature, args) do
    signature
    |> ABI.encode(args)
    |> Encoding.to_hex()
  end

  defp encode_all_integer_opts(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> is_integer(v) end)
    |> Enum.into(opts, fn {k, v} -> {k, Encoding.to_hex(v)} end)
  end
end
