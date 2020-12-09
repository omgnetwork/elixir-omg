defmodule OMG.Conformance.MixProject do
  use Mix.Project

  def project() do
    version =
      "git"
      |> System.cmd(["describe", "--tags", "--abbrev=0"])
      |> elem(0)
      |> String.replace("v", "")
      |> String.replace("\n", "")

    [
      app: :omg_conformance,
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

  def application() do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp deps() do
    [
      {:propcheck, "~> 1.1", only: [:test]},
      {:omg, in_umbrella: true}
    ]
  end
end
