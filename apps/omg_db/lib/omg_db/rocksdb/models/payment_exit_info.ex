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

defmodule OMG.DB.RocksDB.Models.PaymentExitInfo do
  @moduledoc """
  RocksDB implementation for PaymentExitInfo model.
  """

  @behaviour OMG.DB.Models.PaymentExitInfo

  require Logger

  @server_name OMG.DB.RocksDB.Server

  @one_minute 60_000

  def exit_info(utxo_pos, server_name \\ @server_name) do
    GenServer.call(server_name, {:get, :exit_info, utxo_pos}, @one_minute)
  end

  def exit_infos(server_name \\ @server_name) do
    _ = Logger.info("Reading exits' info, this might take a while. Allowing #{inspect(@one_minute)} ms")
    GenServer.call(server_name, {:get_all_by_type, :exit_info}, @one_minute)
  end

  def in_flight_exits_info(server_name \\ @server_name) do
    _ = Logger.info("Reading in flight exits' info, this might take a while. Allowing #{inspect(@one_minute)} ms")
    GenServer.call(server_name, {:get_all_by_type, :in_flight_exit_info}, @one_minute)
  end
end
