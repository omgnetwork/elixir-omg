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

defmodule OMG.Watcher.Integration.BadChildChainBLock do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      use JSONRPC2.Server.Handler
      alias OMG.JSONRPC.Client

      def port, do: 9657

      def handle_request(method, params) do
        param_hash = params["hash"]

        if param_hash == Base.encode16(bad_block_hash()) do
          bad_block() |> Client.encode()
        else
          with {:ok, decoded} <- Base.decode16(param_hash, case: :mixed),
               {:ok, response} <- Client.call(:get_block, %{hash: decoded}, "http://localhost:9656") do
            Client.encode(response)
          end
        end
      end

      def bad_block do
        %{
          hash: bad_block_hash(),
          number: unquote(opts)[:blknum],
          transactions: [
            <<248, 207, 130, 89, 216, 128, 128, 128, 128, 128, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 148, 59, 159, 76, 29, 210, 110, 11, 229, 147, 55, 59, 29, 54, 206, 226, 0, 140, 190, 184, 55, 10,
              148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 184, 65, 78, 238, 201, 119, 140,
              175, 144, 102, 238, 15, 237, 102, 173, 107, 218, 170, 53, 26, 229, 37, 114, 8, 232, 78, 126, 253, 246,
              194, 246, 163, 1, 61, 107, 180, 151, 3, 169, 206, 155, 191, 18, 63, 131, 254, 92, 228, 74, 136, 154, 240,
              11, 44, 13, 44, 204, 81, 52, 213, 235, 85, 137, 116, 7, 204, 28, 184, 65, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
          ]
        }
      end

      defp bad_block_hash do
        <<246, 35, 54, 64, 210, 93, 125, 143, 215, 90, 74, 44, 247, 117, 121, 168, 159, 1, 108, 10, 14, 6, 231, 126, 50,
          136, 186, 67, 229, 8, 197, 232>>
      end
    end
  end
end
