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

defmodule OMG.Watcher.Web.Controller.Challenge do
  @moduledoc """
  Handles exit challenges
  """

  use OMG.Watcher.Web, :controller

  alias OMG.Watcher.Challenger
  alias OMG.Watcher.Web.View

  import OMG.Watcher.Web.ErrorHandler

  @doc """
  Challenges exits
  """
  def challenge(conn, %{"blknum" => blknum, "txindex" => txindex, "oindex" => oindex}) do
    {blknum, ""} = Integer.parse(blknum)
    {txindex, ""} = Integer.parse(txindex)
    {oindex, ""} = Integer.parse(oindex)

    Challenger.create_challenge(blknum, txindex, oindex)
    |> respond(conn)
  end

  defp respond({:ok, challenge}, conn) do
    render(conn, View.Challenge, :challenge, challenge: challenge)
  end

  defp respond({:error, code}, conn) do
    handle_error(conn, code)
  end
end
