defmodule OmiseGO.Eth.MixProject do
  use Mix.Project

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
    mixfile_path = File.cwd!()

    [
      {:abi, git: "https://github.com/omisego/abi.git", branch: "add_bytes32"},
      {:ethereumex, git: "https://github.com/omisego/ethereumex.git", branch: "request_timeout", override: true},
      {:exexec, git: "https://github.com/paulperegud/exexec.git", branch: "add_streams", runtime: true},
      {
        :plasma_mvp_contracts,
        git: "https://github.com/omisego/plasma-mvp.git",
        ref: "2c1d6d324ea164b2081c628170da4bae59c9018e",
        sparse: "plasma/root_chain/contracts/",
        compile: "cd #{mixfile_path}/../../populus && #{solc_binary_override()} populus compile",
        app: false,
        only: [:dev, :test]
      }
    ]
  end

  defp solc_binary_override do
    default = Path.join(System.get_env("HOME"), "/.py-solc/solc-#{@default_solc_version}/bin/solc")

    cond do
      # user overrode the binary themselves, no need to re-override
      System.get_env("solc_binary_override") ->
        ""

      # revert to whatever populus installed at specific version, if ${HOME} is present
      File.exists?(default) ->
        "SOLC_BINARY=" <> default

      # no other default - never want to use `solc` in `PATH`
      true ->
        raise(CompileError, "Can't find solc, define either SOLC_BINARY or follow populus/README.md")
    end
  end
end
