defmodule OMG.Status.Mixfile do
  use Mix.Project

  def project do
    [
      app: :omg_status,
      version: OMG.Umbrella.MixProject.umbrella_version(),
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
      extra_applications: [:logger, :sasl, :os_mon]
    ]
  end

  defp deps,
    do: [
      {:telemetry_metrics_statsd, "~> 0.2.0"},
      {:telemetry_poller, "~> 0.4.0"}
    ]
end
