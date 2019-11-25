# NOTE: This class is auto generated by OpenAPI Generator (https://openapi-generator.tech).
# https://openapi-generator.tech
# Do not edit the class manually.

defmodule WatcherSecurityCriticalAPI.Connection do
  @moduledoc """
  Handle Tesla connections for WatcherSecurityCriticalAPI.
  """

  use Tesla

  # Add any middleware here (authentication)
  plug(Tesla.Middleware.BaseUrl, "https://watcher.ari.omg.network")
  plug(Tesla.Middleware.Headers, [{"user-agent", "Elixir"}])
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
