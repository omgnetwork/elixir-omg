defmodule OMG.Status.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :omg_status,
      version: "#{String.trim(File.read!("../../VERSION"))}",
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
      {:telemetry, "~> 0.4.0"},
      {:sentry, "~> 7.0"},
      {:statix, git: "https://github.com/omisego/statix.git", branch: "otp-21.3.8.4-support-global-tag-patch"},
      {:spandex_datadog, "~> 0.4"},
      {:decorator, "~> 1.2"},
      {:vmstats, "~> 2.3", runtime: false},
      {:ink, "~> 1.0"},
      # umbrella apps
      {:omg_bus, in_umbrella: true}
    ]
end
