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

defmodule OMG.PlasmaDeploymentHeight do
  @moduledoc """
  Hold the state of the contract deployment height or handle by raising an alarm, if
  the contract is not deployed on the blockchain.
  Raises either :contract_not_ready or :contract_deployment_issue. Normally both, but
  they don't point to the same issue. :contract_deployment_issue alarm might mean the configuration is faulty!
  """
  use GenServer
  alias OMG.Eth
  require Logger

  @default_interval 60_00
  @type t :: %__MODULE__{
          interval: pos_integer(),
          tref: reference() | nil,
          alarm_module: module(),
          # contract status
          raised_height: boolean(),
          raised_contract_deployment: boolean(),
          # block number at which the contract was deployed
          height: pos_integer() | nil,
          # is the contract available
          contract_ready: boolean()
        }
  defstruct interval: @default_interval,
            tref: nil,
            alarm_module: nil,
            raised_height: true,
            raised_contract_deployment: true,
            height: nil,
            contract_ready: false

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([alarm_module]) do
    _ = Logger.info("Starting #{__MODULE__}.")
    install()
    state = %__MODULE__{alarm_module: alarm_module}
    _ = alarm_module.set({:contract_height, Node.self(), __MODULE__})
    _ = alarm_module.set({:contract_deployment_issue, Node.self(), __MODULE__})
    {height, contract_ready} = check()
    {height, is_valid_height, availability, is_available} = validate(height, contract_ready)
    raised_height = not is_valid_height
    raised_contract_availability = not is_available
    # if is_valid_height, do: _ = alarm_module.clear({:contract_height, Node.self(), __MODULE__})
    # if is_available, do: _ = alarm_module.clear({:contract_deployment_issue, Node.self(), __MODULE__})
    raise_clear(state.alarm_module, :contract_height, state.raised_height, is_valid_height)
    raise_clear(state.alarm_module, :contract_deployment_issue, state.raised_contract_deployment, is_available)
    {:ok, tref} = :timer.send_after(state.interval, :health_check)
    {:ok,
     %{
       state
       | height: height,
         contract_ready: availability,
         raised_height: raised_height,
         raised_contract_deployment: raised_contract_availability,
         tref: tref
     }}
  end

  # gen_event
  def init(_args) do
    {:ok, %{}}
  end

  def handle_info(:health_check, state) do
    {height, contract_ready} = check()
    {height, is_valid_height, availability, is_available} = validate(height, contract_ready)
    IO.inspect state
    IO.inspect {height, is_valid_height, availability, is_available}
    # if is_valid_height, do: _ = state.alarm_module.clear({:contract_height, Node.self(), __MODULE__})
    # if is_available, do: _ = state.alarm_module.clear({:contract_deployment_issue, Node.self(), __MODULE__})
    raised_height = not is_valid_height
    raised_contract_availability = not is_available
    raise_clear(state.alarm_module, :contract_height, state.raised_height, is_valid_height)
    raise_clear(state.alarm_module, :contract_deployment_issue, state.raised_contract_deployment, is_available)
    {:ok, tref} = :timer.send_after(state.interval, :health_check)

    {:noreply,
     %{
       state
       | height: height,
         contract_ready: availability,
         raised_height: raised_height,
         raised_contract_deployment: raised_contract_availability,
         tref: tref
     }}
  end

  def handle_cast(:clear_contract_deployment_issue, state), do: {:noreply, %{state | raised_contract_deployment: false}}
  def handle_cast(:set_contract_deployment_issue, state), do: {:noreply, %{state | raised_contract_deployment: true}}
  def handle_cast(:clear_contract_height, state), do: {:noreply, %{state | raised_height: false}}
  def handle_cast(:set_contract_height, state), do: {:noreply, %{state | raised_height: true}}

  def terminate(_, _), do: :ok

  #
  # gen_event
  #
  def handle_call(_request, state), do: {:ok, :ok, state}

  def handle_event({:clear_alarm, {:contract_deployment_issue = type, %{reporter: __MODULE__}}}, state) do
    _ = Logger.info("#{__MODULE__} is clearing alarm #{type}.")
    :ok = GenServer.cast(__MODULE__, :clear_contract_deployment_issue)
    {:ok, state}
  end

  def handle_event({:set_alarm, {:contract_deployment_issue = type, %{reporter: __MODULE__}}}, state) do
    _ = Logger.warn("#{__MODULE__} is raising alarm #{type}.")
    :ok = GenServer.cast(__MODULE__, :set_contract_deployment_issue)
    {:ok, state}
  end

  def handle_event({:clear_alarm, {:contract_height = type, %{reporter: __MODULE__}}}, state) do
    _ = Logger.info("#{__MODULE__} is clearing alarm #{type}.")
    :ok = GenServer.cast(__MODULE__, :clear_contract_height)
    {:ok, state}
  end

  def handle_event({:set_alarm, {:contract_height = type, %{reporter: __MODULE__}}}, state) do
    _ = Logger.warn("#{__MODULE__} is raising alarm #{type}.")
    :ok = GenServer.cast(__MODULE__, :set_contract_height)
    {:ok, state}
  end

  # flush
  def handle_event(event, state) do
    _ = Logger.info("#{__MODULE__} got event: #{inspect(event)}. Ignoring.")
    {:ok, state}
  end

  @spec check ::
          {{:ok, pos_integer() | any()}
           | {:ok | {:error, :root_chain_contract_not_available | :root_chain_authority_is_nil}}}
  defp check do
    height = do_height_check()
    availability = do_contract_availability_check()
    {height, availability}
  end

  defp do_height_check, do: eth().get_root_deployment_height()

  defp do_contract_availability_check, do: eth().contract_ready

  # negating validation because we translate them into alarm states
  defp validate(height, availability) do
    {height, is_number(height), availability, availability == :ok}
  end

  defp eth, do: Application.get_env(:omg, :eth_integration_module, Eth)

  defp install do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__)
    end
  end

  @spec raise_clear(module(), :contract_deployment_issue | :contract_height, boolean(), boolean()) ::
          :ok | :duplicate
  defp raise_clear(_alarm_module, _type, true, false), do: :ok

  defp raise_clear(alarm_module, type, false, false),
    do: alarm_module.set({type, Node.self(), __MODULE__})

  defp raise_clear(alarm_module, type, true, _),
    do: alarm_module.clear({type, Node.self(), __MODULE__})

  defp raise_clear(_alarm_module, _type, false, _), do: :ok
end
