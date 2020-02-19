defmodule LoadTest.Connection.WatcherSecurity do
  @moduledoc """
  Modele that overrides the Tesla middleware with the url in config.
  """

  def client() do
    base_url = Application.get_env(:load_test, :watcher_security_url)

    middleware = [
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.EncodeJson, engine: Poison},
      {Tesla.Middleware.Headers, [{"user-agent", "Elixir"}]}
    ]

    Tesla.client(middleware)
  end
end
