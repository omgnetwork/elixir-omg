# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherRPC.Web.Controller.Block do
    @moduledoc """
    Operations related to block.
    """
  
    use OMG.WatcherRPC.Web, :controller
  
    alias OMG.WatcherInfo.API.Block, as: InfoApiBlock
  
    def get_block(conn, params) do
        with {:ok, id} <- expect(params, "id", :hash) do 
          id 
          |> InfoApiBlock.get()
          |> api_response(conn, :block)
        end
    end
end