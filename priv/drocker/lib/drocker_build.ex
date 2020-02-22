defmodule DrockerBuild do
  require Logger

  def build(:docker) do
    Enum.each(["docker-child_chain", "docker-watcher", "docker-watcher_info"], fn item ->
      exexec_opts_for_mix = [
        stdout: :stream,
        cd: "/opt/Omise/elixir-omg/",
        # group 0 will create a new process group, equal to the OS pid of that process
        group: 0,
        kill_group: true
      ]

      {:ok, _process, _ref, [{:stream, stream_out, _stream_server}]} =
        Exexec.run_link("make #{item} 2>&1", exexec_opts_for_mix)
      log_prefix = "(make #{item})"
      wait_for_start(
        stream_out,
        [
          "Release successfully built!"
        ],log_prefix
      )

      Task.async(fn ->
        Enum.each(stream_out, &log_output(log_prefix, &1))
      end)
    end)
  end

  defp wait_for_start(outstream, look_for_all, log_prefix) do
    [line] = Enum.take(outstream, 1)
    log_output(log_prefix, line)
    lefover = is_ready(line, look_for_all)

    case look_for_all -- lefover do
      [] -> :done
      rest -> wait_for_start(outstream, rest, log_prefix)
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
