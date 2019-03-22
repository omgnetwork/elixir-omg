# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Eth.DevMiningHelper do
  @moduledoc """
  Sends small tx every second, causing Ethereum node in `--dev` mode to create new blocks.
  Basically helps to simulate behavior of `geth --dev --dev.period 1`. Useful with parity.
  """
  @devperiod_ms 1000

  use GenServer

  def start do
    GenServer.start(__MODULE__, [:ok], name: __MODULE__)
  end

  def init(_) do
    {:ok, acc, passphrase} = create_tick_account()
    {:ok, %{forced_height: 0, account: acc, passphrase: passphrase}, {:continue, :continue}}
  end

  def handle_continue(:continue, state) do
    :timer.send_interval(@devperiod_ms, :timer)
    {:noreply, state}
  end

  def handle_info(:timer, %{forced_height: counter, account: acc, passphrase: passphrase} = state) do
    {:ok, _} = mine(acc, passphrase)
    {:noreply, %{state | forced_height: counter + 1}}
  end

  defp mine(addr, passphrase) do
    %{from: addr, to: addr, value: OMG.Eth.Encoding.to_hex(1)}
    |> OMG.Eth.send_transaction(passphrase: passphrase)
    |> OMG.Eth.DevHelpers.transact_sync!()
  end

  defp create_tick_account do
    tick_acc = generate_entity()
    account_priv_enc = Base.encode16(tick_acc.priv)
    passphrase = "dev.period"

    {:ok, addr} = OMG.Eth.DevHelpers.create_account_from_secret(OMG.Eth.backend(), account_priv_enc, passphrase)

    {:ok, [faucet | _]} = Ethereumex.HttpClient.eth_accounts()

    %{from: faucet, to: addr, value: OMG.Eth.Encoding.to_hex(1_000_000 * trunc(:math.pow(10, 9 + 5)))}
    |> OMG.Eth.send_transaction(passphrase: "")
    |> OMG.Eth.DevHelpers.transact_sync!()

    {:ok, addr, passphrase}
  end

  defp generate_entity do
    priv = :crypto.strong_rand_bytes(32)
    {:ok, <<4::integer-size(8), pub::binary>>} = Blockchain.Transaction.Signature.get_public_key(priv)
    {:ok, addr} = generate_address(pub)
    %{priv: priv, addr: addr}
  end

  defp generate_address(<<pub::binary-size(64)>>) do
    <<_::binary-size(12), address::binary-size(20)>> = hash(pub)
    {:ok, address}
  end

  defp hash(message), do: message |> ExthCrypto.Hash.hash(ExthCrypto.Hash.kec())
end
