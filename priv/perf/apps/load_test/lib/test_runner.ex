defmodule LoadTest.TestRunner do
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
