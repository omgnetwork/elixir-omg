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

defmodule OMG.DB.Models.PaymentExitInfo do
  @moduledoc """
  DB API module that provides an interface to Payment (V1) Exit Info.
  """

  @callback exit_infos() :: {:ok, list(term)}
  @callback in_flight_exits_info() :: {:ok, list(term)}

  @callback exit_info({pos_integer, non_neg_integer, non_neg_integer}) :: {:ok, map} | :not_found
  @callback exit_infos(GenServer.server()) :: {:ok, list(term)} | {:error, any}
  @callback in_flight_exits_info(GenServer.server()) :: {:ok, list(term)} | {:error, any}
  @callback exit_info({pos_integer, non_neg_integer, non_neg_integer}, GenServer.server()) ::
              {:ok, map} | :not_found

  @optional_callbacks exit_infos: 1,
                      in_flight_exits_info: 1,
                      exit_info: 2

  def exit_info(utxo_pos), do: driver().exit_info(utxo_pos)
  def exit_info(utxo_pos, server_name), do: driver().exit_info(utxo_pos, server_name)

  def exit_infos(), do: driver().exit_infos()
  def exit_infos(server_name), do: driver().exit_infos(server_name)

  def in_flight_exits_info(), do: driver().in_flight_exits_info()
  def in_flight_exits_info(server_name), do: driver().in_flight_exits_info(server_name)

  defp driver(), do: OMG.DB.RocksDB.Models.PaymentExitInfo
end
