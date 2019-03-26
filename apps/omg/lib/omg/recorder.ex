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

defmodule OMG.Recorder do
  @moduledoc """
  A GenServer template for metrics recording.
  """
  use GenServer
  @default_interval 5_000
  @type t :: %__MODULE__{
          name: atom(),
          parent: pid(),
          key: charlist() | nil,
          interval: pos_integer(),
          reporter: (... -> atom()),
          tref: reference() | nil,
          node: String.t() | nil
        }
  defstruct name: nil,
            parent: nil,
            key: nil,
            interval: @default_interval,
            reporter: &Appsignal.set_gauge/3,
            tref: nil,
            node: nil

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts.name)
  end

  def init(opts) do
    {:ok, tref} = :timer.send_interval(opts.interval, self(), :gather)

    {:ok,
     %{
       opts
       | key: to_charlist(opts.name),
         interval: get_interval(opts.name) || @default_interval,
         tref: tref,
         node: Atom.to_string(:erlang.node())
     }}
  end

  def handle_info(:gather, state) do
    # invoke the reporter function and pass the key and value (invoke the fn)
    _ = state.reporter.(state.key, Process.info(state.parent, :message_queue_len) |> elem(1), %{node: state.node})
    {:noreply, state}
  end

  # check configuration and system env variable, otherwise use the default
  defp get_interval(name) do
    case Application.get_env(:omg_status, String.to_atom("#{name}_interval")) do
      nil ->
        name
        |> Atom.to_string()
        |> String.upcase()
        |> Kernel.<>("_INTERVAL")
        |> System.get_env()

      num ->
        num
    end
  end
end
