defmodule Drocker.MixProject do
  use Mix.Project

  def project do
    [
      app: :drocker,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {DrockerApplication, []},
      extra_applications: [:logger, :exexec]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exexec, git: "https://github.com/pthomalla/exexec.git", branch: "add_streams"}
    ]
  end
end
