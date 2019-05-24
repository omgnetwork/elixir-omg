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

defmodule OMG.RPC.Web.View.Transaction do
  @moduledoc """
  The Transaction submission view for rendering json
  """

  alias OMG.Utils.HttpRPC.Response

  def render("submit.json", %{result: result}) do
    result
    |> Response.sanitize()
    |> Response.serialize()
  end
end
