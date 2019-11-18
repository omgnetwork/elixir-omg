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

defmodule OMG.Watcher.ExitProcessor.TxAppendix do
  @moduledoc """
  Part of the exit processor serving as the API to the transaction appendix

  Transaction appendix (TxAppendix) serves the transactions that were witnessed, but aren't included in the blocks
  """

  alias OMG.Watcher.ExitProcessor

  @doc """
  Enumerable of `Transaction.Signed.t()`
  """
  @type t() :: Enumerable.t()

  @spec get_all(ExitProcessor.Core.t()) :: t()
  def get_all(%ExitProcessor.Core{in_flight_exits: ifes, competitors: competitors}) do
    ifes
    |> Map.values()
    |> Stream.concat(Map.values(competitors))
    |> Stream.map(&Map.get(&1, :tx))
  end
end
