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

defmodule OMG.Eth.RootChain do
  @moduledoc """
  Adapter/port to RootChain contract

  Handles sending transactions and fetching events.

  Should remain simple and not contain any business logic, except being aware of the RootChain contract(s) APIs.
  """

  require Logger
  import OMG.Eth.Encoding, only: [to_hex: 1, from_hex: 1, int_from_hex: 1]

  alias OMG.Eth
  alias OMG.Eth.Configuration
  alias OMG.Eth.RootChain.Abi
  alias OMG.Eth.RootChain.Rpc

  @type optional_address_t() :: %{atom => Eth.address()} | %{atom => nil}

  def get_mined_child_block() do
    child_block_interval = Configuration.child_block_interval()
    mined_num = next_child_block()
    mined_num - child_block_interval
  end

  def next_child_block() do
    contract_address = Configuration.contracts().plasma_framework
    %{"block_number" => mined_num} = get_external_data(contract_address, "nextChildBlock()", [])
    mined_num
  end

  def blocks(mined_num) do
    contract_address = Configuration.contracts().plasma_framework

    %{"block_hash" => block_hash, "block_timestamp" => block_timestamp} =
      get_external_data(contract_address, "blocks(uint256)", [mined_num])

    {block_hash, block_timestamp}
  end

  @doc """
  Returns lists of block submissions from Ethereum logs	
  """
  def get_block_submitted_events(from_height, to_height) do
    contract = from_hex(Configuration.contracts().plasma_framework)
    signature = "BlockSubmitted(uint256)"
    {:ok, logs} = Rpc.get_ethereum_events(from_height, to_height, signature, contract)

    {:ok, Enum.map(logs, &Abi.decode_log(&1))}
  end

  ##
  ## these two cannot be parsed with ABI decoder!
  ##
  @doc """
  Returns standard exits data from the contract for a list of `exit_id`s. Calls contract method.
  """
  def get_standard_exit_structs(exit_ids) do
    contract = Configuration.contracts().payment_exit_game

    return_types = [
      {:array, {:tuple, [:bool, {:uint, 256}, {:bytes, 32}, :address, {:uint, 256}, {:uint, 256}]}}
    ]

    # TODO: hack around an issue with `ex_abi` https://github.com/poanetwork/ex_abi/issues/22
    #       We procure a hacky version of `OMG.Eth.Client.call_contract` which strips the offending offsets from
    #       the ABI-encoded binary and proceeds to decode the array without the offset
    #       Revert to `call_contract` when that issue is resolved
    call_contract_manual_exits(
      contract,
      "standardExits(uint160[])",
      [exit_ids],
      return_types
    )
  end

  @doc """
  Returns in flight exits of the specified ids. Calls a contract method.
  """
  def get_in_flight_exit_structs(in_flight_exit_ids) do
    contract = Configuration.contracts().payment_exit_game
    {:array, {:tuple, [:bool, {:uint, 256}, {:bytes, 32}, :address, {:uint, 256}, {:uint, 256}]}}

    # solidity does not return arrays of structs
    return_types = [
      {:array, {:tuple, [:bool, {:uint, 64}, {:uint, 256}, {:uint, 256}, :address, {:uint, 256}, {:uint, 256}]}}
    ]

    call_contract_manual_exits(
      contract,
      "inFlightExits(uint160[])",
      [in_flight_exit_ids],
      return_types
    )
  end

  ########################
  # MISC #
  ########################

  @spec get_root_deployment_height() ::
          {:ok, integer()} | Ethereumex.HttpClient.error()
  def get_root_deployment_height() do
    plasma_framework = Configuration.contracts().plasma_framework
    txhash = Configuration.txhash_contract()

    case Ethereumex.HttpClient.eth_get_transaction_receipt(txhash) do
      {:ok, %{"contractAddress" => ^plasma_framework, "blockNumber" => height}} ->
        {:ok, int_from_hex(height)}

      {:ok, _} ->
        {:error, :wrong_contract_address}

      other ->
        other
    end
  end

  # TODO: see above in where it is called - temporary function
  defp call_contract_manual_exits(contract, signature, args, return_types) do
    data = ABI.encode(signature, args)

    {:ok, return} = Ethereumex.HttpClient.eth_call(%{to: contract, data: to_hex(data)})
    decode_answer_manual_exits(return, return_types)
  end

  # TODO: see above in where it is called - temporary function
  defp decode_answer_manual_exits(enc_return, return_types) do
    <<32::size(32)-unit(8), raw_array_data::binary>> = from_hex(enc_return)
    [single_return] = ABI.TypeDecoder.decode(raw_array_data, return_types)
    {:ok, single_return}
  end

  defp get_external_data(contract_address, signature, args) do
    {:ok, data} = Rpc.call_contract(contract_address, signature, args)
    Abi.decode_function(data, signature)
  end
end
