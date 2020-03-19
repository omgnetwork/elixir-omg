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
if Code.ensure_loaded?(WatcherInfoAPI.Connection) do
  # override Tesla connection module if it exists because it's pointing to localhost
  Code.compiler_options(ignore_module_conflict: true)

  defmodule WatcherInfoAPI.Connection do
    @moduledoc """
    Handle Tesla connections for WatcherInfoAPI.
    """

    use Tesla

    # Add any middleware here (authentication)
    plug(Tesla.Middleware.BaseUrl, "http://localhost:7534")
    plug(Tesla.Middleware.Headers, [{"user-agent", "Itest-Elixir"}])
    plug(Tesla.Middleware.EncodeJson, engine: Poison)

    @doc """
    Configure an authless client connection

    # Returns

    Tesla.Env.client
    """
    @spec new() :: Tesla.Env.client()
    def new() do
      Tesla.client([])
    end
  end
end
