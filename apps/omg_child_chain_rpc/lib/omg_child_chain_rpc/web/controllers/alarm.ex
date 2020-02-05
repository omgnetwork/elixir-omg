# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.ChildChainRPC.Web.Controller.Alarm do
  @moduledoc """
  Module provides operation related to the child chain raised alarms that might point to
  faulty childchain node.
  """

  use OMG.ChildChainRPC.Web, :controller

  alias OMG.ChildChain.API.Alarm

  def get_alarms(conn, _params) do
    {:ok, alarms} = Alarm.get_alarms()
    api_response(alarms, conn, :alarm)
  end
end
