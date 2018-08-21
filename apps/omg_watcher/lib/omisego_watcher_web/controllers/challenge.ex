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

defmodule OMGWatcherWeb.Controller.Challenge do
  @moduledoc """
  Handles exit challenges
  """

  use OMGWatcherWeb, :controller

  alias OMGWatcher.Challenger.Challenge

  @doc """
  Challenges exits
  """
  def challenge(conn, %{"blknum" => blknum, "txindex" => txindex, "oindex" => oindex}) do
    {blknum, ""} = Integer.parse(blknum)
    {txindex, ""} = Integer.parse(txindex)
    {oindex, ""} = Integer.parse(oindex)

    challenge = OMGWatcher.Challenger.create_challenge(blknum, txindex, oindex)

    respond_single(challenge, conn)
  end

  defp respond_single(%Challenge{} = challenge, conn), do: json(conn, challenge)

  defp respond_single(:exit_valid, conn) do
    conn
    |> put_status(400)
    |> json(%{error: "exit is valid"})
  end
end
