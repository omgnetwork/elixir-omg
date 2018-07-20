defmodule OmiseGO.Eth.MixProject do
  use Mix.Project

  require Logger

  def project do
    [
      app: :omisego_eth,
      version: "0.1.0",
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
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:abi, git: "https://github.com/omisego/abi.git", branch: "encode_dynamic_types"},
      {:ethereumex, git: "https://github.com/omisego/ethereumex.git", branch: "request_timeout", override: true},
      {:exexec, git: "https://github.com/pthomalla/exexec.git", branch: "add_streams", runtime: true},
      {:briefly, "~> 0.3", only: [:dev, :test]},
      {
        :plasma_contracts,
        git: "https://github.com/omisego/plasma-contracts",
        branch: "develop",
        sparse: "contracts/",
        compile: contracts_compile(),
        app: false,
        only: [:dev, :test]
      }
    ]
  end

  defp contracts_compile do
    case solc_binary_override() do
      :no_solc ->
        Logger.warn(
          "Can't find solc, contracts may not compile. " <>
            "If you need contracts, either define SOLC_BINARY or follow populus/README.md to install solc"
        )

        false

      solc_override ->
        populus_compile_command(solc_override)
    end
  end

  defp populus_compile_command(solc_override) do
    mixfile_path = File.cwd!()

    case System.cmd("which", ["populus"]) do
      {_, 0} ->
        "cd #{mixfile_path}/../../populus && #{solc_override} populus compile"

      {_, 1} ->
        Logger.warn(
          "Can't find populus, contracts may not compile. " <>
            "If you need contracts, ensure you have populus in path (see populus/README.md)"
        )

        false
    end
  end

  defp solc_binary_override do
    # NOTE: used to default to a populus-frozen version. To revert to that, see blame

    cond do
      # user overrode the binary themselves, no need to re-override
      System.get_env("SOLC_BINARY") ->
        ""

      # revert to one installed in path
      match?({_, 0}, System.cmd("which", ["solc"])) ->
        ""

      # no other default - never want to use `solc` from `$PATH`
      true ->
        :no_solc
    end
  end
end
