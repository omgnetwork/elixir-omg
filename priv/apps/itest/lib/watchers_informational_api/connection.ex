if Code.ensure_loaded?(WatchersInformationalAPI.Connection) do
  Code.compiler_options(ignore_module_conflict: true)

  defmodule WatchersInformationalAPI.Connection do
    @moduledoc """
    Handle Tesla connections for ChildChainAPI.
    """

    use Tesla

    # Add any middleware here (authentication)
    plug(Tesla.Middleware.BaseUrl, "http://localhost:7434")
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
