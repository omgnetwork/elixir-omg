# Copyright 2019-2019 OmiseGO Pte Ltd
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

defmodule OMG.Status.ReleaseTasks.SetSentry do
  @moduledoc false
  use Distillery.Releases.Config.Provider
  alias OMG.Utils.CLI

  @impl Provider
  def init(_args) do
    app_env = System.get_env("APP_ENV")
    sentry_dsn = System.get_env("SENTRY_DSN")

    :ok =
      case {is_binary(app_env), is_binary(sentry_dsn)} do
        {true, true} ->
          CLI.info("Sentry configuration provided. Enabling Sentry.")
          Application.put_env(:sentry, :included_environments, [app_env], persistent: true)

        _ ->
          CLI.info("Sentry configuration not provided. Disabling Sentry.")
          Application.put_env(:sentry, :included_environments, [], persistent: true)
      end
  end

  :ok
end
