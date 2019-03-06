defmodule Status.Metric.Recorder do
  @moduledoc """
  A GenServer template for metrics recording.
  """
  use GenServer
  @default_interval 5_000
  @type t :: %__MODULE__{
          name: atom(),
          fn: (... -> atom()),
          key: charlist(),
          interval: pos_integer(),
          reporter: (... -> atom()),
          tref: reference(),
          node: charlist()
        }
  defstruct name: nil, fn: nil, key: nil, interval: @default_interval, reporter: nil, tref: nil, node: nil

  @doc """
  Returns child_specs for the given metric setup, to be included e.g. in Supervisor's children.
  """
  @spec prepare_child(t) :: %{id: atom(), start: tuple()}
  def prepare_child(opts \\ []) do
    %{id: opts.name, start: {__MODULE__, :start_link, [opts]}}
  end

  # Initialization
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
         node: to_charlist(:erlang.node())
     }}
  end

  def handle_info(:gather, state) do
    # invoke the reporter function and pass the key and value (invoke the fn)
    _ = state.reporter.(state.key, apply(state.fn(), []), %{node: to_charlist(:erlang.node())})
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
