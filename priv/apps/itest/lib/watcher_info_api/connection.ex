if Code.ensure_loaded?(WatcherInformationalAPI.Connection) do
  # override Tesla connection module if it exists because it's pointing to localhost
  Code.compiler_options(ignore_module_conflict: true)

  defmodule WatcherInformationalAPI.Connection do
    @moduledoc """
    Handle Tesla connections for WatcherInformationalAPI.
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
    def new do
      Tesla.client([])
    end
  end
end
