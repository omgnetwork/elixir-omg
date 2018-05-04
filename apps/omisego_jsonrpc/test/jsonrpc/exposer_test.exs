#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

defmodule OmiseGO.JSONRPC.ExposerTest do
  @moduledoc """
  Tests whether given an ExposeSpec-conformant API module, the exposer can serve a JSONRPC.Server.Handler
  """
  use ExUnit.Case

  defmodule ExampleAPI do
    use OmiseGO.API.ExposeSpec

    @spec is_even_N(x :: integer) :: {:ok, boolean} | {:error, :badarg}
    def is_even_N(x) when x > 0 and is_integer(x) do
      {:ok, rem(x, 2) == 0}
    end

    def is_even_N(_) do
      {:error, :badarg}
    end

    @spec is_even_list(x :: [integer]) :: {:ok, boolean} | {:error, :badarg}
    def is_even_list(x) when is_list(x) do
      {:ok, Enum.all?(x, fn x -> rem(x, 2) == 0 end)}
    end

    def is_even_list(_) do
      {:error, :badarg}
    end

    @spec is_map_values_even(x :: %{:atom => integer}) :: {:ok, boolean} | {:error, :badarg}
    def is_map_values_even(x) when is_map(x) do
      checker = fn x -> rem(x, 2) == 0 end
      {:ok, Enum.all?(Map.values(x), checker)}
    end

    def is_map_values_even(_) do
      {:error, :badarg}
    end
  end

  # SUT (System Under Test):
  defmodule ExampleHandler do
    use JSONRPC2.Server.Handler

    def handle_request(method, params) do
      OmiseGO.JSONRPC.Exposer.handle_request_on_api(method, params, ExampleAPI)
    end
  end

  test "sane handler" do
    f = fn x ->
      {:reply, rep} = JSONRPC2.Server.Handler.handle(ExampleHandler, Poison, x)
      {:ok, decoded} = Poison.decode(rep)
      decoded
    end

    assert %{"result" => true} = f.(~s({"method": "is_even_N", "params": {"x": 26}, "id": 1, "jsonrpc": "2.0"}))
    assert %{"result" => true} = f.(~s({"method": "is_even_list", "params": {"x": [2, 4]}, "id": 1, "jsonrpc": "2.0"}))
    assert %{"result" => false} = f.(~s({"method": "is_map_values_even", "params": {"x": {"a": 97, "b": 98}},
             "id": 1, "jsonrpc": "2.0"}))
    assert %{"result" => false} = f.(~s({"method": "is_even_N", "params": {"x": 1}, "id": 1, "jsonrpc": "2.0"}))

    assert %{"error" => %{"code" => -32_603}} =
             f.(~s({"method": "is_even_N", "params": {"x": -1}, "id": 1, "jsonrpc": "2.0"}))

    assert %{
             "error" => %{
               "code" => -32_601,
               "data" => %{"method" => ":lists.filtermap"},
               "message" => "Method not found"
             }
           } = f.(~s({"method": ":lists.filtermap", "params": {"x": -1}, "id": 1, "jsonrpc": "2.0"}))
  end
end
