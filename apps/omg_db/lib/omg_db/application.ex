# Copyright 2018 OmiseGO Pte Ltd
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

  def start(_type, _args) do
    db_path = Application.fetch_env!(:omg_db, :leveldb_path)
    server_module = Application.fetch_env!(:omg_db, :server_module)
    server_name = Application.fetch_env!(:omg_db, :server_name)

    children = [
      {server_module, name: server_name, db_path: db_path}
    ]

    opts = [strategy: :one_for_one, name: OMG.DB.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_phase(phase, start_type, phase_args),
    do: IO.puts("top_app:start_phase(#{inspect(phase)},#{inspect(start_type)},#{inspect(phase_args)}).")
end
