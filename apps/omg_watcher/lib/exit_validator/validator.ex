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
    Contains 'challenge_fastly_invalid_exits' and 'challenge_slowly_invalid_exits' functions
    used for current exit validation design which consits of `FastValidator` and `SlowValidator`.

    See docs/exit_validation.md for more information.
  """
  use OMG.API.LoggerExt

  alias OMG.API.EventerAPI
  alias OMG.API.Utxo
  alias OMG.Watcher.Eventer.Event
  require Utxo

  @doc """
    Validates exits and pushes them to `DB.EthEvent`. if exit is invalid then emits `:invalid_exit` event
  """
  @spec challenge_fastly_invalid_exits :: ([OMG.API.State.Core.exit_t()] -> :ok)
  def challenge_fastly_invalid_exits do
    challenge_invalid_exits(false)
  end

  @doc """
    Validates and spends exits in the "OMG.API.State" and if exit is invalid then emits `:invalid_exit` event
  """
  @spec challenge_slowly_invalid_exits :: (fun() -> :ok)
  def challenge_slowly_invalid_exits do
    challenge_invalid_exits(true)
  end

  defp challenge_invalid_exits(is_slow_validator) do
    fn utxo_exits ->
      _ = Enum.map(utxo_exits, &challenge_invalid_exit(&1, is_slow_validator))
      :ok
    end
  end

  defp challenge_invalid_exit(utxo_exit, is_slow_validator) do
    cond do
      not OMG.API.State.utxo_exists?(utxo_exit) ->
        EventerAPI.emit_events([struct(Event.InvalidExit, utxo_exit)])

      not is_slow_validator ->
        _ = OMG.Watcher.DB.EthEvent.insert_exits([utxo_exit])

      is_slow_validator ->
        :ok = OMG.API.State.exit_utxos([utxo_exit])
        _ = Logger.info(fn -> "Spent exit: #{inspect(utxo_exit)}" end)
    end
  end
end
