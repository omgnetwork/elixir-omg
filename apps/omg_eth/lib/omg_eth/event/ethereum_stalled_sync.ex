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

defmodule OMG.Eth.Event.EthereumStalledSync do
  @moduledoc """
  Notifies about a stalled Ethereum sync.
  """

  @type t :: %__MODULE__{
          ethereum_height: non_neg_integer(),
          synced_at: DateTime.t(),
          name: atom()
        }

  defstruct [:ethereum_height, :synced_at, name: :ethereum_stalled_sync]
end
