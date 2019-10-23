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

defmodule Support.DevMiningHelper do
  @moduledoc """
  Sends small tx every second, causing Ethereum node in `--dev` mode to create new blocks.
  Basically helps to simulate behavior of `geth --dev --dev.period 1`. Useful with parity.
  """

  alias OMG.Crypto
  alias OMG.DevCrypto
  alias OMG.Eth.Encoding
  alias Support.DevHelper

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
    data = %{from: addr, to: addr, value: Encoding.to_hex(1)}

    OMG.Eth.Transaction.send(backend(), data, passphrase: passphrase)
    |> DevHelper.transact_sync!()
  end

  defp create_tick_account() do
    tick_acc = generate_entity()
    account_priv_enc = Base.encode16(tick_acc.priv)
    passphrase = "dev.period"

    {:ok, addr} = DevHelper.create_account_from_secret(backend(), account_priv_enc, passphrase)

    {:ok, [faucet | _]} = Ethereumex.HttpClient.eth_accounts()

    data = %{from: faucet, to: addr, value: Encoding.to_hex(1_000_000 * trunc(:math.pow(10, 9 + 5)))}

    OMG.Eth.Transaction.send(backend(), data, passphrase: "")
    |> DevHelper.transact_sync!()

    {:ok, addr, passphrase}
  end

  defp generate_entity() do
    # lausy way of getting around circular dependency between omg_eth and omg
    {:ok, priv} = apply(DevCrypto, :generate_private_key, [])
    {:ok, pub} = apply(DevCrypto, :generate_public_key, [priv])
    {:ok, address} = apply(Crypto, :generate_address, [pub])
    %{priv: priv, addr: address}
  end

  defp backend() do
    Application.fetch_env!(:omg_eth, :eth_node)
  end
end
