# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Eth do
  @moduledoc """
  Adapter/port to contracts deployed on Ethereum.

  """
  import OMG.Eth.Encoding
  alias OMG.Eth.WaitFor

  @type address :: <<_::160>>

  @type tx_option :: {tx_option_key, non_neg_integer}
  @type tx_option_key :: :nonce | :value | :gasPrice | :gas

  # safe, reasonable amount, equal to the testnet block gas limit
  @lots_of_gas 4_712_388

  @gas_price 20_000_000_000

  # TODO: such timeout works only in dev setting; on mainnet one must track its transactions carefully
  @about_4_blocks_time 60_000

  def get_ethereum_height do
    case Ethereumex.HttpClient.eth_block_number() do
      {:ok, "0x" <> height_hex} ->
        {height, ""} = Integer.parse(height_hex, 16)
        {:ok, height}

      other ->
        other
    end
  end

  def call_contract_value(contract, signature) do
    with {:ok, values} <- call_contract(contract, signature, [], [{:uint, 256}]), {value} = values, do: {:ok, value}
  end

  def call_contract(contract, signature, args, return_types) do
    data = signature |> ABI.encode(args) |> Base.encode16()

    with {:ok, return} <- Ethereumex.HttpClient.eth_call(%{to: contract, data: "0x#{data}"}),
         "0x" <> enc_return = return,
         do: decode_answer(enc_return, return_types)
  end

  def decode_answer(enc_return, return_types) do
    return =
      enc_return
      |> Base.decode16!(case: :lower)
      |> ABI.TypeDecoder.decode_raw(return_types)
      |> List.to_tuple()

    {:ok, return}
  end

  @spec contract_transact(address, address, binary, [any], [tx_option]) :: {:ok, binary} | {:error, any}
  def contract_transact(from, to, signature, args, opts \\ []) do
    opts =
      tx_defaults()
      |> Map.merge(Map.new(opts))
      |> Enum.map(fn {k, v} -> {k, encode_eth_rpc_unsigned_int(v)} end)
      |> Map.new()

    data = encode_tx_data(signature, args)

    txmap =
      %{from: from, to: to, data: "0x" <> data}
      |> Map.merge(opts)

    Ethereumex.HttpClient.eth_send_transaction(txmap)
  end

  def contract_transact_sync!(from, to, signature, args, opts \\ []) do
    {:ok, txhash} = contract_transact(from, to, signature, args, opts)
    {:ok, %{"status" => "0x1"}} = WaitFor.eth_receipt(txhash, @about_4_blocks_time)
  end

  def get_bytecode!(path_project_root, contract_name) do
    %{"evm" => %{"bytecode" => %{"object" => bytecode}}} =
      path_project_root
      |> read_contracts_json!(contract_name)
      |> Poison.decode!()

    "0x" <> bytecode
  end

  defp encode_tx_data(signature, args) do
    args = args |> Enum.map(&cleanup/1)

    signature
    |> ABI.encode(args)
    |> Base.encode16()
  end

  defp encode_constructor_params(args, types) do
    args = for arg <- args, do: cleanup(arg)

    args
    |> ABI.TypeEncoder.encode_raw(types)
    |> Base.encode16(case: :lower)
  end

  def cleanup("0x" <> hex), do: hex |> String.upcase() |> Base.decode16!()
  def cleanup(raw), do: raw

  def deploy_contract(addr, bytecode, types, args, gas) do
    enc_args = encode_constructor_params(types, args)
    txmap = %{from: addr, data: bytecode <> enc_args, gas: gas}

    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)

    {:ok, %{"contractAddress" => contract_address, "status" => "0x1"}} =
      WaitFor.eth_receipt(txhash, @about_4_blocks_time)

    {:ok, txhash, contract_address}
  end

  defp tx_defaults, do: %{value: 0, gasPrice: @gas_price, gas: @lots_of_gas}

  defp read_contracts_json!(path_project_root, contract_name) do
    path = "contracts/build/#{contract_name}.json"

    case File.read(Path.join(path_project_root, path)) do
      {:ok, contract_json} ->
        contract_json

      {:error, reason} ->
        raise(
          RuntimeError,
          "Can't read #{path} because #{inspect(reason)}, try running mix deps.compile plasma_contracts"
        )
    end
  end
end
