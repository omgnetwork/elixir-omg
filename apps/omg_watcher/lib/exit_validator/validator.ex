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
  use OMG.API.LoggerExt

  alias OMG.API.EventerAPI
  alias OMG.API.Utxo
  alias OMG.Watcher.Eventer.Event
  require Utxo

  @spec challenge_fastly_invalid_exits() :: (fun() -> :ok)
  def challenge_fastly_invalid_exits() do
    challenge_invalid_exits(fn utxo_exit ->
      IO.inspect {:challenge_fastly_invalid_exits, utxo_exit}
      if not OMG.API.State.utxo_exists?(utxo_exit) do
        emit_invalid_exit_event(utxo_exit)
      end
    end)
  end

  @spec challenge_slowly_invalid_exits() :: (fun() -> :ok)
  def challenge_slowly_invalid_exits() do
    challenge_invalid_exits(fn utxo_exit ->
      IO.inspect {:challenge_slowly_invalid_exits, utxo_exit}
      with :ok <- OMG.API.State.exit_if_not_spent(utxo_exit) do
        _ = Logger.info(fn -> "Spent exit: #{inspect(utxo_exit)}" end)
      else
        :utxo_does_not_exist ->
          emit_invalid_exit_event(utxo_exit)

        other ->
          other
      end
    end)
  end

  defp challenge_invalid_exits(utxo_exists_callback) do
    fn utxo_exits ->
      for utxo_exit <- utxo_exits do
        utxo_exists_callback.(utxo_exit)
      end

      :ok
    end
  end

  defp emit_invalid_exit_event(utxo_exit) do
    EventerAPI.emit_events([struct(Event.InvalidExit, utxo_exit)])
  end
end
