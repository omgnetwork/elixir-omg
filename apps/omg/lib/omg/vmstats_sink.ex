defmodule OMG.VmstatsSink do

  @behaviour :vmstats_sink

  def collect(:counter, key, value) do
    OMG.Utils.Metrics.Statix.set(key, value)
  end

  def collect(:gauge, key, value) do
    OMG.Utils.Metrics.Statix.gauge(key, value)
  end

  def collect(:timing, key, value) do
    OMG.Utils.Metrics.Statix.timing(key, value)
  end
end
