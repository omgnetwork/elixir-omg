defmodule DrockerStart do
  require Logger

  def start() do
    exexec_opts_for_mix = [
      stdout: :stream,
      cd: "/opt/Omise/elixir-omg/",
      # group 0 will create a new process group, equal to the OS pid of that process
      group: 0,
      kill_group: true
    ]

    {:ok, docker_compose_up, _ref, [{:stream, docker_compose_up_stream_out, _stream_server}]} =
      Exexec.run_link(
        "docker-compose up 2>&1",
        exexec_opts_for_mix
      )

    wait_for_start(
      docker_compose_up_stream_out,
      [
        ["watcher_1", "Running OMG.WatcherRPC.Web.Endpoint"],
        ["watcher_info_1", "Running OMG.WatcherRPC.Web.Endpoint"],
        "OMG.ChildChainRPC.Web.Endpoint"
      ]
    )

    Task.async(fn ->
      Enum.each(docker_compose_up_stream_out, &log_output("(docker-compose up)", &1))
    end)

    docker_compose_up
  end

  def stop() do
    exexec_opts_for_mix = [
      stdout: :stream,
      cd: "/opt/Omise/elixir-omg/",
      # group 0 will create a new process group, equal to the OS pid of that process
      group: 0,
      kill_group: true
    ]

    {:ok, docker_compose_down, _ref, [{:stream, _db_out, _stream_server}]} =
      Exexec.run_link(
        "docker-compose down 2>&1",
        exexec_opts_for_mix
      )

    _ = Process.monitor(docker_compose_down)

    :ok =
      case Exexec.stop_and_wait(docker_compose_down) do
        :normal ->
          :ok

        :shutdown ->
          :ok

        :noproc ->
          :ok
      end
  end

  defp wait_for_start(outstream, look_for_all) do
    [line] = Enum.take(outstream, 1)
    log_output("(docker-compose up)", line)
    lefover = is_ready(line, look_for_all)

    case look_for_all -- lefover do
      [] -> :done
      rest -> wait_for_start(outstream, rest)
    end
  end

  defp is_ready(line, look_for_all) do
    is_ready(line, look_for_all, [])
  end

  defp is_ready(_line, [], acc), do: acc

  defp is_ready(line, [look_for | look_for_all], acc) do
    case Enum.all?(contains(line, look_for)) do
      true -> is_ready(line, look_for_all, [look_for | acc])
      false -> is_ready(line, look_for_all, acc)
    end
  end

  def contains(line, look_for_all) when is_list(look_for_all) do
    Enum.map(look_for_all, fn look_for -> String.contains?(line, look_for) end)
  end

  def contains(line, look_for) do
    [String.contains?(line, look_for)]
  end

  defp log_output(prefix, line) do
    Logger.info("#{prefix}: " <> line)
    line
  end
end
