defmodule Mix.Tasks.Watcher do
  @moduledoc """
    Contains mix.task to run the watcher in different modes:
      a) mix watcher ----> security critical
      b) mix watcher convenient_api ----> security critical + convenient api

    See the docs/TODO file.
  """
  use Mix.Task

  @shortdoc "Starts the watcher. See Mix.Tasks.Watcher for possible options"

  def run(["convenient_api"]) do
    Application.put_env(:omg_watcher, :convenient_api_mode, true, persistent: true)
    start_watcher()
  end

  def run(_) do
    start_watcher()
  end

  defp start_watcher do
    Mix.shell().cmd("cd apps/omg_watcher && iex -S mix run")
  end
end
