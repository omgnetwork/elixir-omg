defmodule OMG.XomgTasks.MixProject do
  @moduledoc """
  This is just a proxy app to hold and use all the code related to running `xomg` Mix.Tasks.

  NOTE: this is not a proper mix app, just some Mix.Tasks which call into other mix apps
  """
  use Mix.Project

  def project do
    [
      app: :xomg_tasks,
      version: "#{version_and_git_revision_hash()}",
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      elixirc_paths: ["lib"],
      start_permanent: false,
      deps: []
    ]
  end

  def application do
    []
  end

  defp version_and_git_revision_hash() do
    {rev, _i} = System.cmd("git", ["rev-parse", "HEAD"])

    sha =
      case rev do
        "" -> System.get_env("CIRCLE_SHA1")
        _ -> String.replace(rev, "\n", "")
      end

    version = String.trim(File.read!("../../VERSION"))

    updated_ver =
      case String.split(version, [".", "-"]) do
        items when length(items) == 3 -> Enum.join(items, ".") <> "-" <> sha
        items -> Enum.join(Enum.take(items, 3), ".") <> "-" <> sha
      end

    :ok = File.write!("../../VERSION", updated_ver)
    updated_ver
  end
end
