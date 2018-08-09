defmodule OmiseGOWatcherWeb.Controller.Challenge do
  @moduledoc """
  Handles exit challenges
  """

  use OmiseGOWatcherWeb, :controller

  alias OmiseGOWatcher.Challenger.Challenge

  @doc """
  Challenges exits
  """
  def challenge(conn, %{"blknum" => blknum, "txindex" => txindex, "oindex" => oindex}) do
    {blknum, ""} = Integer.parse(blknum)
    {txindex, ""} = Integer.parse(txindex)
    {oindex, ""} = Integer.parse(oindex)

    challenge = OmiseGOWatcher.Challenger.create_challenge(blknum, txindex, oindex)

    respond_single(challenge, conn)
  end

  defp respond_single(%Challenge{} = challenge, conn), do: json(conn, challenge)

  defp respond_single(:exit_valid, conn) do
    conn
    |> put_status(400)
    |> json(%{error: "exit is valid"})
  end
end
