# Copyright 2020 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.GasPrice.History do
  @moduledoc """
  Starts the gas price history service and provides gas price records.
  """
  alias OMG.ChildChain.GasPrice.History.Server

  @type t() :: [record()]
  @type record() :: {height :: non_neg_integer(), prices :: [float()], timestamp :: non_neg_integer()}

  @doc """
  Defines the child specification for this module, so that it can be started conveniently by a supervisor.

  ## Examples

      Supervisor.init([{History, []}], strategy: :one_for_one)
  """
  def child_spec(start_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [start_arg]},
      type: :worker
    }
  end

  @doc """
  Start the gas price history service.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(start_arg) do
    {name, start_arg} = Keyword.pop(start_arg, :name, Server)
    GenServer.start_link(Server, start_arg, name: name)
  end

  @doc """
  Get all existing gas price records.
  """
  @spec all() :: t()
  def all() do
    Server.all()
  end
end
