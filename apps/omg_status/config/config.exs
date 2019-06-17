use Mix.Config

config :omg_status,
  metrics: true

config :omg_status, OMG.Utils.Tracer,
  service: :omg_status,
  adapter: SpandexDatadog.Adapter,
  disabled?: false,
  env: Atom.to_string(Mix.env())

config :vmstats,
  base_key: 'vmstats',
  interval: 1000,
  key_separator: '$.',
  sched_time: true,
  memory_metrics: [
    total: :total,
    processes_used: :procs_used,
    atom_used: :atom_used,
    binary: :binary,
    ets: :ets
  ]

import_config "#{Mix.env()}.exs"
