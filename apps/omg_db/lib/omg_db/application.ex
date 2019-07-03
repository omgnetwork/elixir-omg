# Copyright 2019 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.DB.Application do
  @moduledoc false

  use Application
  import Telemetry.Metrics

  def start(_type, _args) do
    DeferredConfig.populate(:omg_db)

    children = [
      {TelemetryMetricsStatsd,
       [
         metrics: [
           last_value("DB.recorder.message_queue_len",
             event_name: "Elixir.OMG.DB.LevelDB.Server.Recorder",
             tags: [:node]
           ),
           last_value("DB.recorder.message_queue_len",
             event_name: "Elixir.OMG.DB.RocksDB.Server.Recorder",
             tags: [:node]
           ),
           last_value("DB.Recorder.message_queue_len.leveldb_write.value",
             event_name: "Elixir.OMG.DB.LevelDB.Server.Recorder",
             tags: [:node]
           ),
           last_value("DB.Recorder.message_queue_len.leveldb_read",
             event_name: "Elixir.OMG.DB.LevelDB.Server.Recorder",
             tags: [:node]
           ),
           last_value("DB.Recorder.message_queue_len.leveldb_multiread",
             event_name: "Elixir.OMG.DB.LevelDB.Server.Recorder",
             tags: [:node]
           ),
           last_value("DB.Recorder.message_queue_len.rocksdb_write",
             event_name: "Elixir.OMG.DB.RocksDB.Server.Recorder",
             tags: [:node]
           ),
           last_value("DB.Recorder.message_queue_len.rocksdb_read",
             event_name: "Elixir.OMG.DB.RocksDB.Server.Recorder",
             tags: [:node]
           ),
           last_value("DB.Recorder.message_queue_len.rocksdb_multiread",
             event_name: "Elixir.OMG.DB.RocksDB.Server.Recorder",
             tags: [:node]
           )
         ],
         formatter: :datadog
       ]},
      OMG.DB.child_spec()
    ]

    opts = [strategy: :one_for_one, name: OMG.DB.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
