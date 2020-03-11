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

defmodule LoadTesting.Connection.WatcherSecurity do
  @moduledoc """
  Module that overrides the Tesla middleware with the url in config.
  """

  alias LoadTesting.Connection.Utils

  def client() do
    base_url = Application.get_env(:load_testing, :watcher_security_url)

    middleware = [
      Tesla.Middleware.Logger,
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.EncodeJson, engine: Poison},
      {Tesla.Middleware.Headers, [{"user-agent", "Perf"}]},
      {Tesla.Middleware.Retry, delay: 500, max_retries: 10, max_delay: 45_000, should_retry: Utils.retry?()},
      {Tesla.Middleware.Timeout, timeout: 30_000},
      {Tesla.Middleware.Opts, [adapter: [recv_timeout: 30_000, pool: :perf_pool]]}
    ]

    Tesla.client(middleware)
  end
end
