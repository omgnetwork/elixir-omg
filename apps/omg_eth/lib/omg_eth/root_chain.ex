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

  alias OMG.Eth
  alias OMG.Eth.Configuration

  require Logger
  import OMG.Eth.Encoding, only: [to_hex: 1, from_hex: 1, int_from_hex: 1]

  @type optional_address_t() :: %{atom => Eth.address()} | %{atom => nil}
  @type in_flight_exit_piggybacked_event() :: %{
          owner: <<_::160>>,
          tx_hash: <<_::256>>,
          output_index: non_neg_integer
        }

  ########################
  # READING THE CONTRACT #
  ########################

  @doc """
  This is what the contract understands as the address of native Ether token
  """
  @spec eth_pseudo_address() :: <<_::160>>
  def eth_pseudo_address(), do: Eth.zero_address()

  #
  # these two cannot be parsed with ABI decoder!
  #
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
    txhash = from_hex(Configuration.txhash_contract())

    case txhash |> to_hex() |> Ethereumex.HttpClient.eth_get_transaction_receipt() do
      {:ok, %{"contractAddress" => ^plasma_framework, "blockNumber" => height}} ->
        {:ok, int_from_hex(height)}

      {:ok, _} ->
        # TODO this should be an alarm
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

    raw_array_data
    |> ABI.TypeDecoder.decode(return_types)
    |> case do
      [single_return] -> {:ok, single_return}
      other when is_list(other) -> {:ok, List.to_tuple(other)}
    end
  end
end
