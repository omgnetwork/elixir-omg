# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.DB.RocksDBCase do
  @moduledoc """
  Defines the useful common setup for all `...PersistenceTests`:
   - creates temp dir with `briefly`
   - initializes the low-level LevelDB storage and starts the test DB server
  """

  use ExUnit.CaseTemplate

  setup %{test: test_name} do
    {:ok, dir} = Briefly.create(directory: true)
    # Server.init_storage(dir)
    :ok = OMG.DB.init(dir)
    name = :"TestDB_#{test_name}"
    {:ok, pid} = start_supervised(OMG.DB.child_spec(db_path: dir, name: name), restart: :temporary)
    {:ok, %{db_dir: dir, db_pid: pid, db_pid_name: name}}
  end
end
