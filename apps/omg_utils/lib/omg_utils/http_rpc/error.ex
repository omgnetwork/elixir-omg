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

defmodule OMG.Utils.HttpRPC.Error do
  @moduledoc """
  Provides standard data structure for API Error response
  """
  alias OMG.Utils.HttpRPC.Response

  @doc """
  Serializes error's code and description provided in response's data field.
  """
  @spec serialize(atom() | String.t(), String.t() | nil, map() | nil) :: map()
  def serialize(code, description, app_infos, messages \\ nil) do
    %{
      object: :error,
      code: code,
      description: description
    }
    |> add_messages(messages)
    |> Response.serialize()
    |> Response.add_app_infos(app_infos)
  end

  defp add_messages(data, nil), do: data
  defp add_messages(data, messages), do: Map.put_new(data, :messages, messages)
end
