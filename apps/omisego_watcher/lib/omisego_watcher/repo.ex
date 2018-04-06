defmodule OmiseGOWatcher.Repo do
  use Ecto.Repo, otp_app: :omisego_watcher

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

# FIXME move to more proper place
  defimpl Poison.Encoder, for: Any do
  def encode(%{__struct__: _} = struct, options) do
    map = struct
          |> Map.from_struct
          |> sanitize_map
    Poison.Encoder.Map.encode(map, options)
  end

  defp sanitize_map(map) do
    Map.drop(map, [:__meta__, :__struct__])
  end
end
end
