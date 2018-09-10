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

defmodule OMG.Watcher.ExitValidator.Validator do
  @moduledoc """
  Fragment of imperative shell for ExitValidator. Validates exits.
  """

  alias OMG.API.Utxo
  require Utxo

  @spec challenge_invalid_exits(fun()) :: (fun() -> :ok)
  def challenge_invalid_exits(utxo_exists_callback) do
    fn utxo_exits ->
      for utxo_exit <- utxo_exits do
        if OMG.API.State.utxo_exists?(utxo_exit) do
          utxo_exists_callback.(utxo_exit)
        else
          :challenged = OMG.Watcher.Challenger.challenge(utxo_exit)
        end
      end

      :ok
    end
  end
end
