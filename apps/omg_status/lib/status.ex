defmodule OMG.Status do
  use Application
  #  alias OMG.Status.Alert.AlarmHandler
  alias Status.Metric.Recorder

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children =
      [
        {:erlang_schedulers, fn -> :erlang.system_info(:schedulers) end},
        {:erlang_uptime, fn -> :erlang.statistics(:wall_clock) |> elem(0) |> Kernel.div(1000) end},
        {:erlang_io_input_kb,
         fn ->
           {{:input, input}, {:output, _output}} = :erlang.statistics(:io)
           input |> Kernel.div(1024)
         end},
        {:erlang_io_output_kb,
         fn ->
           {{:input, _input}, {:output, output}} = :erlang.statistics(:io)
           output |> Kernel.div(1024)
         end},
        {:erlang_total_run_queue_lengths, fn -> :erlang.statistics(:total_run_queue_lengths) end},
        {:erlang_atom_count, fn -> :erlang.system_info(:atom_count) end},
        {:erlang_process_count, fn -> :erlang.system_info(:process_count) end},
        {:erlang_port_count, fn -> :erlang.system_info(:port_count) end},
        {:erlang_ets_count, fn -> length(:ets.all()) end}
      ]
      |> Enum.map(fn {name, invoke} ->
        Recorder.prepare_child(%Recorder{
          name: name,
          fn: invoke,
          reporter: &Appsignal.set_gauge/2
        })
      end)

    opts = [strategy: :one_for_one, name: Status.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
