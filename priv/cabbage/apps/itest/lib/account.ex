# Copyright 2019-2020 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Itest.Account do
  @moduledoc """
    Maintaining used accounts state so that we're able to run tests multiple times.
  """

  alias Itest.Transactions.Encoding
  import Itest.Poller, only: [wait_on_receipt_confirmed: 1]

  @spec take_accounts(integer()) :: map()
  def take_accounts(number_of_accounts) do
    1..number_of_accounts
    |> Task.async_stream(fn _ -> account() end,
      timeout: 240_000,
      on_timeout: :kill_task,
      max_concurrency: System.schedulers_online() * 2
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp account() do
    tick_acc = generate_entity()
    account_priv_enc = Base.encode16(tick_acc.priv)
    passphrase = "dev.period"

    {:ok, addr} = create_account_from_secret(account_priv_enc, passphrase)

    {:ok, [faucet | _]} = with_retries(fn -> Ethereumex.HttpClient.eth_accounts() end)

    data = %{from: faucet, to: addr, value: Encoding.to_hex(1_000_000 * trunc(:math.pow(10, 9 + 5)))}

    {:ok, receipt_hash} = with_retries(fn -> Ethereumex.HttpClient.eth_send_transaction(data) end)

    wait_on_receipt_confirmed(receipt_hash)

    if Application.get_env(:cabbage, :reorg) do
      {:ok, true} =
        with_retries(fn ->
          Ethereumex.HttpClient.request("personal_unlockAccount", [addr, "dev.period", 0], url: "http://localhost:9000")
        end)

      {:ok, true} =
        with_retries(fn ->
          Ethereumex.HttpClient.request("personal_unlockAccount", [addr, "dev.period", 0], url: "http://localhost:9001")
        end)
    else
      {:ok, true} =
        with_retries(fn ->
          Ethereumex.HttpClient.request("personal_unlockAccount", [addr, "dev.period", 0], [])
        end)
    end

    {addr, account_priv_enc}
  end

  defp generate_entity() do
    {:ok, priv} = generate_private_key()
    {:ok, pub} = generate_public_key(priv)
    {:ok, address} = generate_address(pub)
    %{priv: priv, addr: address}
  end

  defp generate_private_key(), do: {:ok, :crypto.strong_rand_bytes(32)}

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

  defp hash(message), do: ExthCrypto.Hash.hash(message, ExthCrypto.Hash.kec())

  defp create_account_from_secret(secret, passphrase) do
    if Application.get_env(:cabbage, :reorg) do
      with_retries(fn ->
        Ethereumex.HttpClient.request("personal_importRawKey", [secret, passphrase], url: "http://localhost:9000")
      end)

      with_retries(fn ->
        Ethereumex.HttpClient.request("personal_importRawKey", [secret, passphrase], url: "http://localhost:9001")
      end)
    else
      with_retries(fn ->
        Ethereumex.HttpClient.request("personal_importRawKey", [secret, passphrase], [])
      end)
    end
  end

  def with_retries(func, total_time \\ 510, current_time \\ 0) do
    case func.() do
      {:ok, _} = result ->
        result

      result ->
        if current_time < total_time do
          Process.sleep(1_000)
          with_retries(func, total_time, current_time + 1)
        else
          result
        end
    end
  end
end
