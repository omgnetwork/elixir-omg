defmodule LoadTest.Connection.ChildChain do
  @moduledoc """
  Module that overrides the Tesla middleware with the url in config.
  """

  alias LoadTest.Connection.Utils

  def client() do
    base_url = Application.get_env(:load_test, :child_chain_url)

    middleware = [
      Tesla.Middleware.Logger,
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.EncodeJson, engine: Jason},
      {Tesla.Middleware.Headers, [{"user-agent", "Perf"}]},
      {Tesla.Middleware.Retry, delay: 500, max_retries: 10, max_delay: 45_000, should_retry: Utils.retry?()},
      {Tesla.Middleware.Timeout, timeout: 30_000},
      {Tesla.Middleware.Opts, [adapter: [recv_timeout: 30_000, pool: :perf_pool]]}
    ]

    Tesla.client(middleware)
  end
end
