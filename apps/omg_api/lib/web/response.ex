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
defmodule OMG.API.Web.Response do
  @type response_t :: %{version: binary(), success: boolean(), data: map()}

  @doc """
  Append result of operation to the response data forming standard api response structure
  """
  @spec serialize(any()) :: response_t()
  def serialize(%{object: :error} = error), do: error |> to_response(:error)
  def serialize(data), do: data |> to_response(:success)

  defp to_response(data, result),
    do: %{
      version: "1.0",
      success: result == :success,
      data: data
    }

end
