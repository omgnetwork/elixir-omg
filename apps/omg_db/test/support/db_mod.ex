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
defmodule OMG.DB.TestDBAdapter do
  @moduledoc """
  Loads the apprioriate DB Case depending on what's
  loaded or not.
  """
  alias OMG.DB.LevelDBCase
  alias OMG.DB.RocksDBCase

  def get_loaded_db do
    cond do
      Code.ensure_loaded?(RocksDBCase) ->
        :rocksdb

      Code.ensure_loaded?(LevelDBCase) ->
        :leveldb

      true ->
        raise "RocksDB and LevelDB are both excluded. Exiting..."
    end
  end

  def get_db_case_mod do
    case get_loaded_db() do
      :rocksdb ->
        RocksDBCase

      :leveldb ->
        LevelDBCase
    end
  end
end
