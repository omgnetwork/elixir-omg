defmodule OMG.Status.Mixfile do
  use Mix.Project

  def project do
    [
      app: :omg_status,
      version: "#{version_and_git_revision_hash()}",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {OMG.Status.Application, []},
      start_phases: [{:install_alarm_handler, []}],
      extra_applications: [:logger, :sasl, :os_mon, :statix, :telemetry],
      included_applications: [:vmstats]
    ]
  end

  defp deps,
    do: [
      {:telemetry, "~> 0.4.0"},
      {:sentry, "~> 7.0"},
      {:statix, "~> 1.1"},
      {:spandex_datadog, "~> 0.4"},
      {:decorator, "~> 1.2"},
      {:vmstats, "~> 2.3", runtime: false},
      # umbrella apps
      {:omg_bus, in_umbrella: true}
    ]

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
