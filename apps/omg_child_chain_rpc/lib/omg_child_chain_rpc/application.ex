# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.ChildChainRPC.Application do
  @moduledoc false

  alias OMG.ChildChainRPC.Plugs.Health
  alias OMG.ChildChainRPC.Web.Endpoint

  use Application
  require Logger

  def start(_type, _args) do
    DeferredConfig.populate(:omg_child_chain_rpc)

    _ = Logger.info("Started application #{__MODULE__}")

    opts = [strategy: :one_for_one, name: OMG.ChildChainRPC.Supervisor]

    children = [
      {Health, []},
      {Endpoint, []}
    ]

    _ = Logger.warn("Is Sentry for OMG.ChildChainRPC.Web.Endpoint enabled: #{System.get_env("SENTRY_DSN") != nil}")

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OMG.ChildChainRPC.Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
