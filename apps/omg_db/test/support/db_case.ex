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

defmodule OMG.DB.Case do
  @moduledoc """
  Defines the useful common setup for all `...PersistenceTests`:
   - starts temporary file handler `:briefly`
   - creates temp dir with that
   - initializes the low-level LevelDB storage and starts the test DB server
  """

  use ExUnit.CaseTemplate

  setup_all do
    {:ok, _} = Application.ensure_all_started(:briefly)
    :ok
  end

  setup %{test: test_name} do
    {:ok, dir} = Briefly.create(directory: true)
    :ok = OMG.DB.LevelDBServer.init_storage(dir)

    {:ok, pid} = GenServer.start_link(OMG.DB.LevelDBServer, %{db_path: dir}, name: :"TestDB_#{test_name}")
    {:ok, %{db_dir: dir, db_pid: pid}}
  end
end
