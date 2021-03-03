# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.API.Account do
  @moduledoc """
  Module provides operations related to plasma accounts.
  """

  alias OMG.DB.Models.PaymentExitInfo
  alias OMG.Watcher.Utxo
  require OMG.Watcher.Utxo

  @doc """
  Gets all utxos belonging to the given address. Slow operation.
  """
  @spec get_exitable_utxos(OMG.Crypto.address_t()) :: list(OMG.Watcher.State.Core.exitable_utxos())
  def get_exitable_utxos(address) do
    # OMG.DB.utxos() takes a while.
    {:ok, utxos} = OMG.DB.utxos()
    standard_exitable_utxos = OMG.Watcher.State.Core.standard_exitable_utxos(utxos, address)

    # PaymentExitInfo.all_exit_infos() takes a while.
    {:ok, standard_exits} = PaymentExitInfo.all_exit_infos()
    {:ok, in_flight_exits} = PaymentExitInfo.all_in_flight_exits_infos()

    # See issue for more details: https://github.com/omgnetwork/private-issues/issues/41
    active_exiting_utxos =
      MapSet.union(
        OMG.Watcher.ExitProcessor.Core.active_standard_exiting_utxos(standard_exits),
        OMG.Watcher.ExitProcessor.Core.active_in_flight_exiting_inputs(in_flight_exits)
      )

    # active standard exiting utxos are excluded
    filter_standard_exiting_utxos(standard_exitable_utxos, active_exiting_utxos)
  end

  defp filter_standard_exiting_utxos(standard_exitable_utxos, active_exiting_utxos) do
    Enum.filter(
      standard_exitable_utxos,
      fn %{blknum: blknum, txindex: txindex, oindex: oindex} ->
        not MapSet.member?(active_exiting_utxos, Utxo.position(blknum, txindex, oindex))
      end
    )
  end
end
