defmodule OMG.WatcherSecurity.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    start_root_supervisor()
  end

  def start_root_supervisor do
    # root supervisor must stop whenever any of its children supervisors goes down (children carry the load of restarts)
    children = [
      %{
        id: OMG.WatcherSecurity.Supervisor,
        start: {OMG.WatcherSecurity.Supervisor, :start_link, []},
        restart: :permanent,
        type: :supervisor
      }
    ]

    opts = [
      strategy: :one_for_one,
      # whenever any of supervisor's children goes down, so it does
      max_restarts: 0,
      name: OMG.WatcherSecurity.RootSupervisor
    ]

    Supervisor.start_link(children, opts)
  end

  def start_phase(:attach_telemetry, :normal, _phase_args) do
    handlers = [
      [
        "spandex-query-tracer",
        [[:omg, :watcher, :db, :repo, :query]],
        &SpandexEcto.TelemetryAdapter.handle_event/4,
        nil
      ],
      [
        "measure-watcher-eventer",
        OMG.WatcherSecurity.Eventer.Measure.supported_events(),
        &OMG.WatcherSecurity.Eventer.Measure.handle_event/4,
        nil
      ],
      ["measure-state", OMG.State.Measure.supported_events(), &OMG.State.Measure.handle_event/4, nil],
      [
        "measure-blockgetter",
        OMG.WatcherSecurity.BlockGetter.Measure.supported_events(),
        &OMG.WatcherSecurity.BlockGetter.Measure.handle_event/4,
        nil
      ],
      [
        "measure-ethereum-event-listener",
        OMG.EthereumEventListener.Measure.supported_events(),
        &OMG.EthereumEventListener.Measure.handle_event/4,
        nil
      ]
    ]

    Enum.each(handlers, fn handler ->
      case apply(:telemetry, :attach_many, handler) do
        :ok -> :ok
        {:error, :already_exists} -> :ok
      end
    end)
  end
end
