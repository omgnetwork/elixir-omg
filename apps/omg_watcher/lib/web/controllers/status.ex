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

defmodule OMG.Watcher.Web.Controller.Status do
  @moduledoc """
  Module provides operation related to childchain health status, like: geth syncing status, last minned block
  number and time and last block verified by watcher.
  """

  use OMG.Watcher.Web, :controller

  alias OMG.API.State
  alias OMG.Eth
  alias OMG.Watcher.Web.View

  import OMG.Watcher.Web.ErrorHandler

  @doc """
  Gets plasma network and Watcher status
  """
  def get(conn, _params) do
    with {:ok, last_mined_child_block_number} <- Eth.get_mined_child_block(),
         {:ok, {_root, last_mined_child_block_timestamp}} <- Eth.get_child_chain(last_mined_child_block_number) do

      status = %{
        last_validated_child_block_number: State.get_current_child_block_height(),
        last_mined_child_block_number: last_mined_child_block_number,
        last_mined_child_block_timestamp: last_mined_child_block_timestamp,
        eth_syncing: Eth.syncing?()
      }

      respond({:ok, status},conn)
#   FIXME
#    else
#      error -> respond(error, conn)
    end
  end

  defp respond({:ok, status}, conn) do
    render(conn, View.Status, :status, status: status)
  end

#  FIXME
#  defp respond({:error, code, description}, conn) do
#    handle_error(conn, code, description)
#  end

end
