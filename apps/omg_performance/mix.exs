defmodule OMG.Performance.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_performance,
      version: OMG.Umbrella.MixProject.umbrella_version(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
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

<<<<<<< HEAD
=======
  # we don't need the performance app in a production release
  defp elixirc_paths(:prod), do: []
  defp elixirc_paths(_), do: ["lib", "test/support"]

>>>>>>> 1ff21130... Merge pull request #617 from omisego/579-otp_release
  defp deps do
    [
      {:briefly, "~> 0.3"},
      {:omg_api, in_umbrella: true, runtime: false},
      {:appsignal, "~> 1.0"},
      {:deferred_config, "~> 0.1.1"}
    ]
  end
end
