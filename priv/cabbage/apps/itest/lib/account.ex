defmodule Itest.Account do
  @moduledoc """
    Maintaining used accounts state so that we're able to run tests multiple times.
  """

  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding
  import Itest.Poller, only: [wait_on_receipt_confirmed: 1]

  def plasma_framework() do
    contracts = parse_contracts()

    contracts["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"]
    |> EIP55.encode()
    |> elem(1)
  end

  @ether_vault_id 1
  def vault_id(currency) do
    ether = Currency.ether()

    case currency do
      ^ether -> @ether_vault_id
    end
  end

  def vault(currency) do
    ether = Currency.ether()

    case currency do
      ^ether -> get_vault(@ether_vault_id)
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

    wait_on_receipt_confirmed(receipt_hash)

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

  defp get_vault(id) do
    data = ABI.encode("vaults(uint256)", [id])
    {:ok, result} = Ethereumex.HttpClient.eth_call(%{to: plasma_framework(), data: Encoding.to_hex(data)})

    result
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([:address])
    |> hd()
    |> Encoding.to_hex()
    |> EIP55.encode()
    |> elem(1)
  end

  # taken from the plasma-contracts deployment snapshot
  # this parsing occurs in several places around the codebase
  defp parse_contracts() do
    local_umbrella_path = Path.join([File.cwd!(), "../../../", "localchain_contract_addresses.env"])

    contract_addreses_path =
      case File.exists?(local_umbrella_path) do
        true ->
          local_umbrella_path

        _ ->
          # CI/CD
          Path.join([File.cwd!(), "localchain_contract_addresses.env"])
      end

    contract_addreses_path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> List.flatten()
    |> Enum.reduce(%{}, fn line, acc ->
      [key, value] = String.split(line, "=")
      Map.put(acc, key, value)
    end)
  end
end
