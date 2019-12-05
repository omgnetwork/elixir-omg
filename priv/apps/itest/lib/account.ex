defmodule Itest.Account do
  @moduledoc """
    Maintaining used accounts state so that we're able to run tests multiple times.
  """

  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding
  import Itest.Poller, only: [wait_on_receipt_confirmed: 2]

  @retry_count 60

  @vault elem(EIP55.encode("0x0433420DEE34412B5Bf1e29FBf988aD037cc5Db7"), 1)
  def vault(), do: @vault

  @plasma_framework elem(EIP55.encode("0xC673e4ffcB8464FaFf908A6804FE0e635AF0ea2f"), 1)
  def plasma_framework(), do: @plasma_framework

  @ether_vault_id 1
  def vault_id(currency) do
    ether = Currency.ether()

    case currency do
      ^ether -> @ether_vault_id
    end
  end

  @spec take_accounts(integer()) :: map()
  def take_accounts(number_of_accounts) do
    1..number_of_accounts
    |> Task.async_stream(fn _ -> account() end, timeout: 60_000, on_timeout: :kill_task)
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp account() do
    tick_acc = generate_entity()
    account_priv_enc = Base.encode16(tick_acc.priv)
    passphrase = "dev.period"

    {:ok, addr} = create_account_from_secret(account_priv_enc, passphrase)

    {:ok, [faucet | _]} = Ethereumex.HttpClient.eth_accounts()

    data = %{from: faucet, to: addr, value: Encoding.to_hex(1_000_000 * trunc(:math.pow(10, 9 + 5)))}

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(data)

    wait_on_receipt_confirmed(receipt_hash, @retry_count)

    {:ok, true} = Ethereumex.HttpClient.request("personal_unlockAccount", [addr, "dev.period", 0], [])

    {addr, account_priv_enc}
  end

  defp generate_entity() do
    {:ok, priv} = generate_private_key()
    {:ok, pub} = generate_public_key(priv)
    {:ok, address} = generate_address(pub)
    %{priv: priv, addr: address}
  end

  defp generate_private_key, do: {:ok, :crypto.strong_rand_bytes(32)}

  defp generate_public_key(<<priv::binary-size(32)>>) do
    {:ok, der_pub} = get_public_key(priv)
    {:ok, der_to_raw(der_pub)}
  end

  defp get_public_key(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  defp der_to_raw(<<4::integer-size(8), data::binary>>), do: data

  defp generate_address(<<pub::binary-size(64)>>) do
    <<_::binary-size(12), address::binary-size(20)>> = hash(pub)
    {:ok, address}
  end

  defp create_account_from_secret(secret, passphrase) do
    Ethereumex.HttpClient.request("personal_importRawKey", [secret, passphrase], [])
  end

  defp hash(message), do: ExthCrypto.Hash.hash(message, ExthCrypto.Hash.kec())
end
