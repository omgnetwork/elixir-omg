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
  alias OMG.Eth.Config

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

  # some constant-like getters to start

  @spec get_child_block_interval() :: {:ok, pos_integer()} | :error
  def get_child_block_interval(), do: Application.fetch_env(:omg_eth, :child_block_interval)

  @doc """
  This is what the contract understands as the address of native Ether token
  """
  @spec eth_pseudo_address() :: <<_::160>>
  def eth_pseudo_address(), do: Eth.zero_address()

  # actual READING THE CONTRACT

  @doc """
  Returns next blknum that is supposed to be mined by operator
  """
  def get_next_child_block(contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    Eth.call_contract(contract, "nextChildBlock()", [], [{:uint, 256}])
  end

  @doc """
  Returns blknum that was already mined by operator (with exception for 0)
  """
  def get_mined_child_block(contract \\ %{}) do
    with {:ok, next} <- get_next_child_block(contract),
         {:ok, interval} <- get_child_block_interval(),
         do: {:ok, next - interval}
  end

  @doc """
  Returns standard exits data from the contract for a list of `exit_id`s. Calls contract method.
  """
  def get_standard_exit_structs(exit_ids, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)

    return_types = [
      {:array, {:tuple, [:bool, {:uint, 256}, {:bytes, 32}, :address, {:uint, 256}, {:uint, 256}]}}
    ]

    # TODO: hack around an issue with `ex_abi` https://github.com/poanetwork/ex_abi/issues/22
    #       We procure a hacky version of `OMG.Eth.call_contract` which strips the offending offsets from
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
  def get_in_flight_exit_structs(in_flight_exit_ids, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
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

  # TODO: we're storing exit_ids for SEs, we should do the same for IFEs and remove this (requires exit_id to be
  #       emitted from the start IFE event
  def get_in_flight_exit_id(tx_bytes, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    Eth.call_contract(contract, "getInFlightExitId(bytes)", [tx_bytes], [{:uint, 160}])
  end

  def get_child_chain(blknum, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    Eth.call_contract(contract, "blocks(uint256)", [blknum], [{:bytes, 32}, {:uint, 256}])
  end

  ########################
  # MISC #
  ########################

  @spec contract_ready(optional_address_t()) ::
          :ok | {:error, :root_chain_contract_not_available | :root_chain_authority_is_nil}
  def contract_ready(contract \\ %{}) do
    {:ok, addr} = authority(contract)

    case addr do
      <<0::256>> -> {:error, :root_chain_authority_is_nil}
      _ -> :ok
    end
  rescue
    error ->
      _ = Logger.error("The call to contract_ready failed with: #{inspect(error)}")
      {:error, :root_chain_contract_not_available}
  end

  # TODO - missing description + could this be moved to a statefull process?
  @spec get_root_deployment_height(binary() | nil, optional_address_t()) ::
          {:ok, integer()} | Ethereumex.HttpClient.error()
  def get_root_deployment_height(txhash \\ nil, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    txhash = txhash || from_hex(Application.fetch_env!(:omg_eth, :txhash_contract))

    # the back&forth is just the dumb but natural way to go about Ethereumex/Eth APIs conventions for encoding
    hex_contract = to_hex(contract)

    case txhash |> to_hex() |> Ethereumex.HttpClient.eth_get_transaction_receipt() do
      {:ok, %{"contractAddress" => ^hex_contract, "blockNumber" => height}} ->
        {:ok, int_from_hex(height)}

      {:ok, _} ->
        # TODO this should be an alarm
        {:error, :wrong_contract_address}

      other ->
        other
    end
  end

  defp authority(contract) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    Eth.call_contract(contract, "authority()", [], [:address])
  end

  # TODO: see above in where it is called - temporary function
  defp call_contract_manual_exits(contract, signature, args, return_types) do
    data = ABI.encode(signature, args)

    {:ok, return} = Ethereumex.HttpClient.eth_call(%{to: to_hex(contract), data: to_hex(data)})
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
