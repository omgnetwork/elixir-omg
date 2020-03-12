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

defmodule OMG.Status.Metric.Statix do
  @moduledoc """
  Useful for overwritting Statix behaviour. The API doesn't change, but the underlying
  connection can be swapped out to use `Kernel.send/2`
  """
  defmacro __using__(_opts) do
    current_conn =
      quote do
        @statix_conn_opts_key Module.concat(__MODULE__, :__statix_conn_opts__)

        def connect() do
          connect(conn: Statix.new_conn(__MODULE__))
        end

        def connect(dd_listener_pid: pid) do
          connect(conn: Statix.new_conn(__MODULE__), dd_listener_pid: pid)
        end

        def connect(conn: conn) do
          statix_conn_opts = %{
            addr: conn.addr,
            port: conn.port,
            prefix: conn.prefix
          }

          statix_conn_opts = if conn[:dd_listener_pid] do
            Map.put(statix_conn_opts, :dd_listener_pid, conn[:dd_listener_pid])
          else
            statix_conn_opts
          end

          Application.put_env(:statix, @statix_conn_opts_key, statix_conn_opts)

          :ok
        end

        @compile {:inline, [current_conn: 0]}
        def current_conn() do
          %{addr: addr, port: port, prefix: prefix} = statix_conn_opts =
            Application.fetch_env!(:statix, @statix_conn_opts_key)

          if Map.has_key?(statix_conn_opts, :dd_listener_pid) do
            %{addr: addr, port: port, prefix: prefix, dd_listener_pid: :dd_listener_pid, sock: __MODULE__}
          else
            %{addr: addr, port: port, prefix: prefix, sock: __MODULE__}
          end
        end
      end

    quote location: :keep do
      @behaviour Statix

      unquote(current_conn)

      def increment(key, val \\ 1, options \\ []) when is_number(val) do
        Statix.transmit(current_conn(), :counter, key, val, options)
      end

      def decrement(key, val \\ 1, options \\ []) when is_number(val) do
        Statix.transmit(current_conn(), :counter, key, [?-, to_string(val)], options)
      end

      def gauge(key, val, options \\ []) do
        Statix.transmit(current_conn(), :gauge, key, val, options)
      end

      def histogram(key, val, options \\ []) do
        Statix.transmit(current_conn(), :histogram, key, val, options)
      end

      def timing(key, val, options \\ []) do
        Statix.transmit(current_conn(), :timing, key, val, options)
      end

      def measure(key, options \\ [], fun) when is_function(fun, 0) do
        {elapsed, result} = :timer.tc(fun)

        timing(key, div(elapsed, 1000), options)

        result
      end

      def set(key, val, options \\ []) do
        Statix.transmit(current_conn(), :set, key, val, options)
      end

      def event(title, text, options \\ []) do
        Statix.transmit(current_conn(), :event, title, text, options)
      end

      def service_check(name, status, options \\ []) do
        Statix.transmit(current_conn(), :service_check, name, status, options)
      end

      defoverridable(
        increment: 3,
        decrement: 3,
        gauge: 3,
        histogram: 3,
        timing: 3,
        measure: 3,
        set: 3,
        event: 3,
        service_check: 3
      )
    end
  end

  def new_conn(module, dd_listener_pid: pid) do
    Map.merge(load_config(module), %{sock: module, dd_listener_pid: pid})
  end

  def new_conn(module) do
    Map.put(load_config(module), :sock, module)
  end

  @doc false
  def transmit(conn, :event, title, text, options)
      when is_binary(title) and is_binary(text) and is_list(options) do
    send(conn[:dd_listener_pid], {:event, title, text, put_global_tags(conn.sock, options)})
  end

  @doc false
  def transmit(conn, :service_check, name, status, options)
      when is_binary(name) and is_atom(status) and is_list(options) do
        send(conn[:dd_listener_pid], {:service_check, name, to_string(status), put_global_tags(conn.sock, options)})
  end

  @doc false
  def transmit(conn, type, key, val, options)
      when (is_binary(key) or is_list(key)) and is_list(options) do
    sample_rate = Keyword.get(options, :sample_rate)

    if is_nil(sample_rate) or sample_rate >= :rand.uniform() do
      send(conn[:dd_listener_pid], {type, key, val, options})
    else
      :ok
    end
  end

  defp load_config(module) do
    {env2, env1} =
      Application.get_all_env(:statix)
      |> Keyword.pop(module, [])

    {prefix1, env1} = Keyword.pop_first(env1, :prefix)
    {prefix2, env2} = Keyword.pop_first(env2, :prefix)
    env = Keyword.merge(env1, env2)

    host = Keyword.get(env, :host, "127.0.0.1")
    port = Keyword.get(env, :port, 8125)
    prefix = build_prefix(prefix1, prefix2)
    {host, port, prefix}
  end

  defp build_prefix(part1, part2) do
    case {part1, part2} do
      {nil, nil} -> ""
      {_p1, nil} -> [part1, ?.]
      {nil, _p2} -> [part2, ?.]
      {_p1, _p2} -> [part1, ?., part2, ?.]
    end
  end

  defp put_global_tags(module, options) do
    conn_tags =
      :statix
      |> Application.get_env(module, [])
      |> Keyword.get(:tags, [])

    app_tags = Application.get_env(:statix, :tags, [])
    global_tags = conn_tags ++ app_tags

    Keyword.update(options, :tags, global_tags, &(&1 ++ global_tags))
  end
end
