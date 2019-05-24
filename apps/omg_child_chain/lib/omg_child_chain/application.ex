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

defmodule OMG.ChildChain.Application do
  @moduledoc """
  The application here is the Child chain server and its API.
  See here (children) for the processes that compose into the Child Chain server.
  """
  use Application

  alias OMG.Alert.Alarm

  require Logger

  def start(_type, _args) do
    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    cookie = System.get_env("ERL_CC_COOKIE")
    true = set_cookie(cookie)
    :ok = Alarm.set(alarm())
    OMG.ChildChain.Supervisor.start_link()
  end

  def start_phase(:boot_done, :normal, _phase_args) do
    :ok = Alarm.clear(alarm())
  end

  defp set_cookie(cookie) when is_binary(cookie) do
    cookie
    |> String.to_atom()
    |> Node.set_cookie()
  end

  defp set_cookie(_), do: :ok == Logger.warn("Cookie not applied.")
  defp alarm, do: {:boot_in_progress, Node.self(), __MODULE__}
end
