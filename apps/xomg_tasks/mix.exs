defmodule OMG.XomgTasks.MixProject do
  @moduledoc """
  This is just a proxy app to hold and use all the code related to running `xomg` Mix.Tasks.

  NOTE: this is not a proper mix app, just some Mix.Tasks which call into other mix apps
  """
  use Mix.Project

  def project() do
    [
      app: :xomg_tasks,
      version: "#{String.trim(File.read!("../../VERSION"))}",
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      elixirc_paths: ["lib"],
      start_permanent: false,
      deps: []
    ]
  end

  def application() do
    [extra_applications: [:iex, :logger]]
  end
end
