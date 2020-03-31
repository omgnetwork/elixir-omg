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

  alias OMG.DB
  alias OMG.Eth.Configuration
  alias OMG.Eth.Metric.Ethereumex

  use Application
  use OMG.Utils.LoggerExt

  def start(_type, _args) do
    _ =
      Logger.info(
        "Started #{inspect(__MODULE__)}, config used: contracts #{inspect(Configuration.contracts())} txhash_contract #{
          inspect(Configuration.txhash_contract())
        } authority_addr #{inspect(Configuration.authority_addr())}"
      )

    valid_contracts()
    OMG.Eth.Supervisor.start_link()
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
    contracts_hash =
      Configuration.contracts()
      |> Map.put(:txhash_contract, Configuration.txhash_contract())
      |> Map.put(:authority_addr, Configuration.authority_addr())
      |> :erlang.phash2()

    case DB.get_single_value(:omg_eth_contracts) do
      result when result == :not_found or result == {:ok, 0} ->
        multi_update = [{:put, :omg_eth_contracts, contracts_hash}]
        :ok == DB.multi_update(multi_update)

      {:ok, ^contracts_hash} ->
        true

      _ ->
        _ = Logger.error("Contract addresses have changed since last boot!")
        exit(:contracts_missmatch)
    end
  end
end
