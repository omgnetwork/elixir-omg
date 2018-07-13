defmodule OmiseGOWatcherWeb.Controller.Challenge do
  @moduledoc """
  Handles exit challenges
  """

  use OmiseGOWatcherWeb, :controller

  alias OmiseGOWatcher.Challenger.Challenge

  @doc """
  Challenges exits
  """
  def challenge(conn, %{"utxo" => utxo}) do
    {utxo, _} = Integer.parse(utxo)

    utxo
    |> OmiseGOWatcher.Challenger.create_challenge()
    |> respond_single(conn)
  end

  defp respond_single(%Challenge{} = challenge, conn), do: json(conn, challenge)

  defp respond_single(:exit_valid, conn) do
    conn
    |> put_status(400)
    |> json(%{error: "exit is valid"})
  end
end
