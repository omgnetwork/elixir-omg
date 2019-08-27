defmodule OMG.Performance.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_performance,
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
      extra_applications: [:logger, :tools]
    ]
  end

  # we don't need the performance app in a production release
  defp elixirc_paths(:prod), do: []
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:deferred_config, "~> 0.1.1"},
      # TEST ONLY
      {:briefly, "~> 0.3.0", only: [:dev, :test], runtime: false},
      {:omg_child_chain, in_umbrella: true, only: [:test], runtime: false},
      {:omg_child_chain_rpc, in_umbrella: true, only: [:test], runtime: false},
      {:omg_watcher, in_umbrella: true, only: [:test], runtime: false},
      {:omg_status, in_umbrella: true, only: [:test], runtime: false}
    ]
  end

  defp version_and_git_revision_hash do
    {rev, _i} = System.cmd("git", ["rev-parse", "HEAD"])
    sha = String.replace(rev, "\n", "") |> Kernel.binary_part(0, 7)
    version = String.trim(File.read!("../../VERSION"))

    updated_ver =
      case String.split(version, [".", "+"]) do
        items when length(items) == 3 -> Enum.join(items, ".") <> "+" <> sha
        items -> Enum.join(Enum.take(items, 3), ".") <> "+" <> sha
      end

    :ok = File.write!("../../VERSION", updated_ver)
    updated_ver
  end
end
