defmodule OMG.ChildChainRPC.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_child_chain_rpc,
      version: "#{version_and_git_revision_hash()}",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
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
      mod: {OMG.ChildChainRPC.Application, []},
      extra_applications: [:logger, :runtime_tools, :sasl, :telemetry]
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
      {:phoenix, "~> 1.3"},
      {:plug_cowboy, "~> 1.0"},
      {:deferred_config, "~> 0.1.1"},
      {:httpoison, "~> 1.4.0"},
      {:cors_plug, "~> 2.0"},
      {:spandex_phoenix, "~> 0.4.1"},
      {:spandex_datadog, "~> 0.4"},
      {:telemetry, "~> 0.4.0"},
      #
      {:omg_bus, in_umbrella: true},
      {:omg_status, in_umbrella: true},
      {:omg_utils, in_umbrella: true},
      {:omg_child_chain, in_umbrella: true}
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
