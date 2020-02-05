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

defmodule OMG.Watcher.API.Configuration do
  @moduledoc """
  Watcher API for retrieving configuration
  """

  alias OMG.Configuration

  @spec get_configuration() :: {:ok, map()}
  def get_configuration() do
    configuration = %{
      deposit_finality_margin: Configuration.deposit_finality_margin(),
      contract_semver: OMG.Eth.Configuration.contract_semver(),
      network: OMG.Eth.Configuration.network(),
      exit_processor_sla_margin: OMG.Watcher.Configuration.exit_processor_sla_margin()
    }

    {:ok, configuration}
  end
end
