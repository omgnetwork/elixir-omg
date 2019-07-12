defmodule OMG.VmstatsSink do
  @behaviour :vmstats_sink

  def collect(:counter, key, value) do
    OMG.Utils.Metrics.set(key, value)
  end

  def collect(:gauge, key, value) do
    OMG.Utils.Metrics.gauge(key, value)
  end

  def collect(:timing, key, value) do
    OMG.Utils.Metrics.timing(key, value)
  end
end
