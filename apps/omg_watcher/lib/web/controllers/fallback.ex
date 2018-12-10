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

defmodule OMG.Watcher.Web.Controller.Fallback do
  @moduledoc """
  The fallback handler.
  """

  use Phoenix.Controller

  alias OMG.RPC.Web.Serializers

  def call(conn, :error), do: call(conn, {:error, :unknown_error})

  def call(conn, {:error, reason}) do
    data = %{
      object: :error,
      code: "#{action_name(conn)}#{inspect(reason)}",
      description: nil
    }

    json(conn, Serializers.Response.serialize(data, :error))
  end
end
