defmodule OMG.ChildChain.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_child_chain,
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
      extra_applications: [:logger, :telemetry],
      start_phases: [{:boot_done, []}, {:attach_telemetry, []}],
      mod: {OMG.ChildChain.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:ex_rlp, "~> 0.5.2"},
      {:deferred_config, "~> 0.1.1"},
      {:telemetry, "~> 0.4.0"},
      #
      {:omg_bus, in_umbrella: true},
      {:omg, in_umbrella: true},
      {:omg_status, in_umbrella: true},
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true},
      {:omg_utils, in_umbrella: true}
    ]
  end

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
