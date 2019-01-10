defmodule OMG.RPC.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_rpc,
      version: OMG.Umbrella.MixProject.umbrella_version(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :phoenix_swagger] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {OMG.RPC.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.2"},
      {:phoenix_swagger, "~> 0.8.1"},
      {:cowboy, "~> 1.1"},
      # NOTE: fixed version needed b/c Plug.Conn.WrapperError.reraise/3 is deprecated... 2 occurences in umbrella.
      {:plug, "1.5.0", override: true},
      {:httpoison, "~> 1.1.0"}
      #
    ]
  end
end
