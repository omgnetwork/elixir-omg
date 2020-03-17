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
defmodule LoadTest.Connection.Utils do
  @moduledoc """
  Utility functions shared between all connection modules
  """

  @doc """
  Returns Tesla middleware common for all connections.
  """
  def middleware(),
    do: [
      Tesla.Middleware.Logger,
      {Tesla.Middleware.EncodeJson, engine: Jason},
      {Tesla.Middleware.Headers, [{"user-agent", "Load-Test"}]},
      {Tesla.Middleware.Retry, delay: 500, max_retries: 10, max_delay: 45_000, should_retry: Utils.retry?()},
      {Tesla.Middleware.Timeout, timeout: 30_000},
      {Tesla.Middleware.Opts, [adapter: [recv_timeout: 30_000, pool: :perf_pool]]}
    ]

  defp retry?() do
    fn
      {:ok, %{status: status}} when status in 400..599 -> true
      {:ok, _} -> false
      {:error, _} -> true
    end
  end
end
