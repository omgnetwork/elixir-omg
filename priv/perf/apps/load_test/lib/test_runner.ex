defmodule LoadTest.TestRunner do
  @moduledoc """
  This module runs tests using `mix run`. For example:

  mix run -e "LoadTest.TestRunner.run()" -- "deposits" "1" "5"

  It accepts three arguments:
  - test name
  - transactions per seconds
  - period in seconds

  It fetches all configuration params from env vars.
  """
  alias LoadTest.TestRunner.Config

  def run() do
    {runner_module, config} = Config.parse()
    result = Chaperon.run_load_test(runner_module, print_results: true, config: config)

    case result.metrics["success_rate"][:mean] do
      1.0 ->
        System.halt(0)

      _ ->
        System.halt(1)
    end
  end
end
