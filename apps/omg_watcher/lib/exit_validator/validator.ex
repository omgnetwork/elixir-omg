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
    resposible for validating exits.

    The exit validators covers following cases:
      a) (FV) The invalid exit is processed after the tx so it's known to be invalid from the start. Causes `:invalid_exit`
      b) (SV) The exit is processed before invalid tx, but invalid tx is within `M_SV, so the chain is valid.
         Causes `:invalid_exit`. Doesn't cause an exit.

  """
  use OMG.API.LoggerExt

  alias OMG.API.EventerAPI
  alias OMG.API.Utxo
  alias OMG.Watcher.Eventer.Event
  require Utxo

  @doc """
    Validates exits and pushes them to `DB.EthEvent`. if exit is invalid then emits `:invalid_exit` event
  """
  @spec challenge_fastly_invalid_exits() :: ([OMG.API.State.Core.exit_t()] -> :ok)
  def challenge_fastly_invalid_exits do
    challenge_invalid_exits(false)
  end

  @doc """
    Validates and spends exits in the "OMG.API.State" and if exit is invalid then emits `:invalid_exit` event
  """
  @spec challenge_slowly_invalid_exits() :: (fun() -> :ok)
  def challenge_slowly_invalid_exits do
    challenge_invalid_exits(true)
  end

  defp challenge_invalid_exits(is_slow_validator) do
    fn utxo_exits ->
      for utxo_exit <- utxo_exits do
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

      :ok
    end
  end
end
