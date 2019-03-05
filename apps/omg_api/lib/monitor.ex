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

defmodule OMG.API.Monitor do
  @moduledoc """
  This module is a custom implemented supervisor that monitors all it's chilldren
  and restarts them based on alarms raised. This means that in the period when Geth alarms are raised
  it would wait before it would restart them.

  When you receive an EXIT, check for an alarm raised that's related to Ethereum client synhronisation or connection
  problems and react accordingly.

  """
  use GenServer

  def start_link(children) do
    GenServer.start_link(__MODULE__, children, name: __MODULE__)
  end

  def init(children) do
    {:ok, children}
  end

  def terminate(_, _), do: :ok
end
