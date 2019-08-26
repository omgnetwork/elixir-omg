defmodule OMG.Bus.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_bus,
      version: "#{version_and_git_revision_hash()}",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      mod: {OMG.Bus.Application, []},
      extra_applications: [:logger],
      included_applications: [:phoenix_pubsub]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]
  defp deps, do: [{:phoenix_pubsub, "~> 1.0"}]

  defp version_and_git_revision_hash() do
    {rev, _i} = System.cmd("git", ["rev-parse", "HEAD"])
    sha = String.replace(rev, "\n", "")
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
