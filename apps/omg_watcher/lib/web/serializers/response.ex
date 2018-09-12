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

defmodule OMG.Watcher.Web.Serializer.Response do
  @moduledoc """
  Serializes the response into expected result/data format.
  """

  alias OMG.Watcher.Web.Serializer.DBObject

  @type response_result_t :: :success | :error

  @doc """

  """
  @spec serialize(map(), response_result_t()) :: %{result: response_result_t(), data: map()}
  def serialize(data, result)
  def serialize(data, :success), do: data |> DBObject.clean() |> to_response(:success)
  def serialize(data, :error), do: data |> to_response(:error)

  defp to_response(data, result), do: %{result: result, data: data}
end
