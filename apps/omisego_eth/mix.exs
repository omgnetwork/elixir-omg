defmodule OmiseGO.Eth.MixProject do
  use Mix.Project

  require Logger

  @default_solc_version "v0.4.18"

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
      {:abi, git: "https://github.com/omisego/abi.git", branch: "add_bytes32"},
      {:ethereumex, git: "https://github.com/omisego/ethereumex.git", branch: "request_timeout", override: true},
      {:exexec, git: "https://github.com/paulperegud/exexec.git", branch: "add_streams", runtime: true},
      {
        :plasma_mvp_contracts,
        git: "https://github.com/omisego/plasma-mvp.git",
        ref: "2c1d6d324ea164b2081c628170da4bae59c9018e",
        sparse: "plasma/root_chain/contracts/",
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
          "Can't find solc, contracts may not compile. NOTE that solc in $PATH is ignored. " <>
            "If you need contracts, either define SOLC_BINARY or follow populus/README.md to install solc in homedir"
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
    default = Path.join(System.get_env("HOME"), "/.py-solc/solc-#{@default_solc_version}/bin/solc")

    cond do
      # user overrode the binary themselves, no need to re-override
      System.get_env("SOLC_BINARY") ->
        ""

      # revert to whatever populus installed at specific version, if ${HOME} is present
      File.exists?(default) ->
        "SOLC_BINARY=" <> default

      # no other default - never want to use `solc` from `$PATH`
      true ->
        :no_solc
    end
  end
end
