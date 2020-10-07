defmodule Front.Runner do
  alias Front.Aggregator

  @required_params [:id, :rate]
  @optional_params [
    :period,
    :period_step,
    :rate_period,
    :adjust_period,
    :error_rate,
    :process_number_limit
  ]

  def run(module, params) do
    {:ok, aggregator} = Aggregator.start_link()
    test_params = Keyword.fetch!(params, :test_params)

    func = fn ->
      result = module.run(test_params)

      Aggregator.record_metrics(aggregator, result)
    end

    runner_params =
      params
      |> Keyword.fetch!(:runner_params)
      |> validate_run_params()
      |> Keyword.put(:func, func)

    {:ok, _pid} = Hornet.start(runner_params)

    aggregator
  end

  defp validate_run_params(params) do
    params
    |> filter_params()
    |> check_required()
  end

  defp filter_params(params) do
    keys = @required_params ++ @optional_params

    params
    |> Enum.filter(fn {key, _value} ->
      key in keys
    end)
    |> Keyword.new()
  end

  defp check_required(params) do
    Enum.each(@required_params, fn key ->
      _ = Keyword.fetch!(params, key)
    end)

    params
  end
end
