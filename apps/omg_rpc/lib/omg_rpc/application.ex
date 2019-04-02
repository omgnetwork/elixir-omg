# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.RPC.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger
  alias OMG.Alert.Alarm

  def start(_type, _args) do
    DeferredConfig.populate(:omg_rpc)

    _ = Logger.info("Started application #{__MODULE__}")

    opts = [strategy: :one_for_one, name: OMG.RPC.Supervisor]

    children = [{OMG.RPC.Plugs.Health, [Alarm]}, {OMG.RPC.Web.Endpoint, []}]

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OMG.RPC.Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
