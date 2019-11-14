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

defmodule OMG.WatcherInformational.DB.Block do
  @moduledoc """
  Ecto schema for Plasma Chain block
  """
  use Ecto.Schema

  alias OMG.WatcherInformational.DB

  @primary_key {:blknum, :integer, []}
  @derive {Phoenix.Param, key: :blknum}
  schema "blocks" do
    field(:hash, :binary)
    field(:eth_height, :integer)
    field(:timestamp, :integer)
  end

  def get_max_blknum do
    DB.Repo.aggregate(__MODULE__, :max, :blknum)
  end
end
