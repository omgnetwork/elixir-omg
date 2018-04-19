defmodule OmiseGO.PerfTest do
  @moduledoc """

  """

  import Supervisor.Spec
  alias OmiseGO.PerfTest.Runner

  @doc """

  """
  def setup_and_run(nrequests, nusers, opt \\ %{}) do
    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)

    children = [
      supervisor(Phoenix.PubSub.PG2, [:eventer, []]),
      {OmiseGO.API.State, []},
      {OmiseGO.API.FreshBlocks, []},

    ]
    Supervisor.start_link(children, [strategy: :one_for_one])

    Runner.run(nrequests, nusers, opt)

    started_apps |> Enum.reverse |> Enum.map(&Application.stop/1)
  end
end
