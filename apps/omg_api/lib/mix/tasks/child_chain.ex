defmodule Mix.Tasks.ChildChain do
  @moduledoc """
    Contains mix.task to run the child chain server
  """

  use Mix.Task

  @shortdoc "Starts the child chain server"
  def run(_) do
    Mix.shell().cmd("cd apps/omg_api && iex -S mix run")
  end
end
