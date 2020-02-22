defmodule Operator do
  use GenServer

  defstruct [:docker_pid, :exec_pid]

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start() do
    GenServer.call(__MODULE__, :start, :infinity)
  end

  def build() do
    GenServer.call(__MODULE__, :build, :infinity)
  end

  def stop() do
    GenServer.call(__MODULE__, :stop, :infinity)
  end

  def init(_) do
    {:ok, exec_pid} = :exec.start_link([])
    {:ok, %__MODULE__{exec_pid: exec_pid}}
  end

  def handle_call(:start, _, state) do
    docker_pid = DrockerStart.start()
    {:reply, :done, %{state | docker_pid: docker_pid}}
  end

  def handle_call(:build, _, state) do
    docker_pid = DrockerBuild.build(:docker)
    {:reply, :done, %{state | docker_pid: docker_pid}}
  end

  def handle_call(:stop, _, state) do
    _ = DrockerStop.stop()
    {:reply, :done, state}
  end
end
