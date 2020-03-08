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

defmodule OMG.Eth.Application do
  @moduledoc false

  alias OMG.Eth
  alias OMG.Eth.Metric.Ethereumex
  alias OMG.Eth.Configuration
  alias OMG.Eth.Supervisor
  use Application
  use OMG.Utils.LoggerExt

  def start(_type, _args) do
    _ = Logger.info("Started #{inspect(__MODULE__)}, config used: #{inspect(Eth.Diagnostics.get_child_chain_config())}")

    true =
      case valid_contracts() do
        true ->
          true

        false ->
          _ = Logger.error("Contract addresses have changed since last boot!")
          false
      end

    Supervisor.start_link()
  end

  def start_phase(:attach_telemetry, :normal, _phase_args) do
    handler = [
      "measure-ethereumex-rpc",
      Ethereumex.supported_events(),
      &Ethereumex.handle_event/4,
      nil
    ]

    case apply(:telemetry, :attach, handler) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  defp valid_contracts() do
    contracts = Configuration.contracts()
    OMG.DB.get_single_value(:omg_eth_contracts)
    # db_update = [{:put, update_key, height_to_check_in}]
    case File.exists?("contracts") do
      true ->
        File.read!("contracts") == :erlang.term_to_binary(contracts)

      false ->
        :ok == File.write!("contracts", :erlang.term_to_binary(contracts))
    end
  end
end
