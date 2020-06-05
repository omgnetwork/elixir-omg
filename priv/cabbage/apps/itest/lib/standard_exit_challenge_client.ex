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

defmodule Itest.StandardExitChallengeClient do
  @moduledoc """
    An interface to Watcher API.
  """
  alias Itest.Transactions.Encoding
  alias WatcherSecurityCriticalAPI.Connection, as: Watcher
  alias WatcherSecurityCriticalAPI.Model.UtxoPositionBodySchema1

  import Itest.Poller, only: [wait_on_receipt_confirmed: 1, pull_api_until_successful: 4]

  use Bitwise
  require Logger

  defstruct [
    :address,
    :utxo_pos,
    :challenge_data,
    :exit_game_contract_address,
    :challenge_standard_exit_hash
  ]

  @gas 540_000

  def challenge_standard_exit(utxo_pos, address) do
    _ = Logger.info("Address #{address} challenging standard exit for UTXO at #{utxo_pos}")

    %__MODULE__{address: address, utxo_pos: utxo_pos}
    |> get_challenge_data()
    |> get_exit_game_contract_address()
    |> do_challenge_standard_exit()
  end

  defp get_challenge_data(%__MODULE__{utxo_pos: utxo_pos} = challenge) do
    payload = %UtxoPositionBodySchema1{utxo_pos: utxo_pos}

    response =
      pull_api_until_successful(WatcherSecurityCriticalAPI.Api.UTXO, :utxo_get_challenge_data, Watcher.new(), payload)

    %{challenge | challenge_data: Itest.ApiModel.ChallengeData.to_struct(response)}
  end

  defp get_exit_game_contract_address(challenge) do
    %{
      challenge
      | exit_game_contract_address: Itest.PlasmaFramework.exit_game_contract_address(ExPlasma.payment_v1())
    }
  end

  defp do_challenge_standard_exit(
         %__MODULE__{
           address: address,
           exit_game_contract_address: exit_game_contract_address,
           challenge_data: challenge_data
         } = challenge
       ) do
    _ = Logger.info("Challenging standard exit.")

    sender_data = address |> Encoding.to_binary() |> :keccakf1600.sha3_256()

    data =
      ABI.encode("challengeStandardExit((uint168,bytes,bytes,uint16,bytes,bytes32))", [
        {challenge_data.exit_id, Encoding.to_binary(challenge_data.exiting_tx),
         Encoding.to_binary(challenge_data.txbytes), challenge_data.input_index, Encoding.to_binary(challenge_data.sig),
         sender_data}
      ])

    txmap = %{
      from: address,
      to: exit_game_contract_address,
      value: Encoding.to_hex(0),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)

    wait_on_receipt_confirmed(receipt_hash)
    %{challenge | challenge_standard_exit_hash: receipt_hash}
  end
end
