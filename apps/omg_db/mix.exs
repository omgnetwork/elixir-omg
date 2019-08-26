defmodule OMG.DB.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_db,
      version: "#{version_and_git_revision_hash()}",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps() ++ rocksdb(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :telemetry],
      start_phases: [{:attach_telemetry, []}],
      mod: {OMG.DB.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:exleveldb, "~> 0.11"},
      {:omg_status, in_umbrella: true},
      # NOTE: we only need in :dev and :test here, but we need in :prod too in performance
      #       then there's some unexpected behavior of mix that won't allow to mix these, see
      #       [here](https://elixirforum.com/t/mix-dependency-is-not-locked-error-when-building-with-edeliver/7069/3)
      #       OMG-373 (Elixir 1.8) should fix this
      # TEST ONLY
      {:briefly, "~> 0.3.0", only: [:dev, :test], runtime: false},
      {:telemetry, "~> 0.4.0"},
      {:omg_utils, in_umbrella: true}
    ]
  end

  defp rocksdb do
    case System.get_env("EXCLUDE_ROCKSDB") do
      nil -> [{:rocksdb, "~> 1.2"}]
      _ -> []
    end
  end

  defp version_and_git_revision_hash() do
    {rev, _i} = System.cmd("git", ["rev-parse", "HEAD"])

    sha =
      case rev do
        "" -> System.get_env("CIRCLE_SHA1")
        _ -> String.replace(rev, "\n", "")
      end

    version = String.trim(File.read!("../../VERSION"))

    updated_ver =
      case String.split(version, [".", "-"]) do
        items when length(items) == 3 -> Enum.join(items, ".") <> "-" <> sha
        items -> Enum.join(Enum.take(items, 3), ".") <> "-" <> sha
      end

    :ok = File.write!("../../VERSION", updated_ver)
    updated_ver
  end
end
