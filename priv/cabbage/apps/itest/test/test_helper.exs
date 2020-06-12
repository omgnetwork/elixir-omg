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

Logger.configure_backend(:console, colors: [enabled: false])
require Logger
alias Itest.Transactions.Currency
alias Itest.Transactions.Encoding
import Itest.Poller, only: [wait_on_receipt_confirmed: 1]

Application.ensure_all_started(:ethereumex)
data = ABI.encode("minExitPeriod()", [])
{:ok, result} = Ethereumex.HttpClient.eth_call(%{to: Itest.PlasmaFramework.address(), data: Encoding.to_hex(data)})

milliseconds =
  result
  |> Encoding.to_binary()
  |> ABI.TypeDecoder.decode([{:uint, 160}])
  |> hd()
  # to milliseconds
  |> Kernel.*(1_000)
  # add three minutes for the rest of the test
  |> Kernel.+(180_000 * 4)

### parse contract addresses:
local_umbrella_path = Path.join([File.cwd!(), "../../../../", "localchain_contract_addresses.env"])

contract_addreses_path =
  case File.exists?(local_umbrella_path) do
    true ->
      local_umbrella_path

    _ ->
      # CI/CD
      Path.join([File.cwd!(), "localchain_contract_addresses.env"])
  end

contracts =
  contract_addreses_path
  |> File.read!()
  |> String.split("\n", trim: true)
  |> List.flatten()
  |> Enum.reduce(%{}, fn line, acc ->
    [key, value] = String.split(line, "=")
    Map.put(acc, key, value)
  end)

Application.put_env(:ex_plasma, :eip_712_domain,
  name: "OMG Network",
  salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
  verifying_contract: contracts["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"],
  version: "1"
)

### add exit queues
gas_add_exit_queue = 800_000
{:ok, [faucet | _]} = Ethereumex.HttpClient.eth_accounts()

has_exit_queue = fn currency ->
  data =
    ABI.encode(
      "hasExitQueue(uint256,address)",
      [Itest.PlasmaFramework.vault_id(currency), currency]
    )

  {:ok, receipt_enc} =
    Ethereumex.HttpClient.eth_call(%{to: Itest.PlasmaFramework.address(), data: Encoding.to_hex(data)})

  receipt_enc
  |> Encoding.to_binary()
  |> ABI.TypeDecoder.decode([:bool])
  |> hd()
end

add_exit_queue = fn symbol, currency ->
  if has_exit_queue.(currency) do
    _ = Logger.info("#{symbol} exit queue was already added.")
    nil
  else
    _ = Logger.info("#{symbol} exit queue missing. Adding...")

    data =
      ABI.encode(
        "addExitQueue(uint256,address)",
        [Itest.PlasmaFramework.vault_id(currency), currency]
      )

    txmap = %{
      from: faucet,
      to: Itest.PlasmaFramework.address(),
      value: Encoding.to_hex(0),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(gas_add_exit_queue)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    wait_on_receipt_confirmed(receipt_hash)
    receipt_hash
  end
end

add_exit_queue.("ETH", Currency.ether())
add_exit_queue.("ERC20", Currency.erc20())

{:ok, _} = Itest.Reorg.start_link()

ExUnit.start(trace: "--trace" in System.argv(), timeout: milliseconds)
