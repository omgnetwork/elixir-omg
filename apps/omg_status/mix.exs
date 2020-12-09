defmodule OMG.Status.Mixfile do
  use Mix.Project

  def project() do
    version = "git"
      |> System.cmd(["describe", "--tags", "--abbrev=0"])
      |> elem(0)
      |> String.replace("v", "")
      |> String.replace("\n", "")

    [
      app: :omg_status,
      version: version,
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

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  def application() do
    [
      mod: {OMG.Status.Application, []},
      start_phases: [{:install_alarm_handler, []}],
      extra_applications: [:logger, :sasl, :os_mon, :statix, :telemetry],
      included_applications: [:vmstats]
    ]
  end

  defp deps(),
    do: [
      {:telemetry, "~> 0.4.1"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_metrics_statsd, "~> 0.3.0"},
      {:sentry, "~> 8.0"},
      {:statix, git: "https://github.com/omgnetwork/statix", branch: "otp-21.3.8.4-support-global-tag-patch"},
      {:spandex_datadog, "~> 1.0"},
      {:decorator, "~> 1.2"},
      {:vmstats, "~> 2.3", runtime: false},
      {:ink, "~> 1.1"},
      # umbrella apps
      {:omg_bus, in_umbrella: true}
    ]
end
