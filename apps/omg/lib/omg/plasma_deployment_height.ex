# # Copyright 2018 OmiseGO Pte Ltd
# #
# # Licensed under the Apache License, Version 2.0 (the "License");
# # you may not use this file except in compliance with the License.
# # You may obtain a copy of the License at
# #
# #     http://www.apache.org/licenses/LICENSE-2.0
# #
# # Unless required by applicable law or agreed to in writing, software
# # distributed under the License is distributed on an "AS IS" BASIS,
# # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# # See the License for the specific language governing permissions and
# # limitations under the License.

# defmodule OMG.PlasmaDeploymentHeight do
#   @moduledoc """
#   Hold the state of the contract deployment height or handle by raising an alarm, if
#   the contract is not deployed on the blockchain.
#   Raises either :contract_not_ready or :contract_deployment_issue. Normally both, but
#   they don't point to the same issue. :contract_deployment_issue alarm might mean the configuration is faulty!
#   """
#   use GenServer
#   require Logger

#   @default_interval 500
#   @type t :: %__MODULE__{
#           interval: pos_integer(),
#           tref: reference() | nil,
#           alarm_module: module(),
#           raised: boolean(),
#           # contract status
#           raised_height: boolean(),
#           raised_contract_availability: boolean(),
#           # block number at which the contract was deployed
#           height: pos_integer() | nil,
#           # is the contract available
#           contract_ready: boolean()
#         }
#   defstruct interval: @default_interval,
#             tref: nil,
#             alarm_module: nil,
#             raised: true,
#             raised_height: true,
#             raised_contract_availability: true,
#             height: nil,
#             contract_ready: false

#   def start_link(args) do
#     GenServer.start_link(__MODULE__, args, name: __MODULE__)
#   end

#   def init([alarm_module]) do
#     _ = Logger.info("Starting #{__MODULE__}.")
#     install()
#     state = %__MODULE__{alarm_module: alarm_module}
#     _ = alarm_module.set({:contract_deployment_issue, Node.self(), __MODULE__})
#     {height, raised_height, contract_ready, raised_contract_availability} = validate(check())
#     _ = raise_clear(alarm_module, state.raised, raised_height && raised_contract_availability)
#     {:ok, tref} = :timer.send_after(state.interval, :health_check)

#     {:ok,
#      %{
#        state
#        | height: height,
#          raised_height: raised_height,
#          contract_ready: contract_ready,
#          raised_contract_availability: raised_contract_availability,
#          tref: tref
#      }}
#   end

#   # gen_event
#   def init(_args) do
#     {:ok, %{}}
#   end

#   def handle_info(:health_check, state) do
#     {height, raised_height, availability, raised_contract_availability} = validate(check())
#     _ = raise_clear(alarm_module, state.raised, raised_height && raised_contract_availability)
#     {:ok, tref} = :timer.send_after(state.interval, :check_deployment)

#     {:ok,
#      %{
#        state
#        | height: height,
#          raised_height: raised_height,
#          contract_ready: contract_ready,
#          raised_contract_availability: raised_contract_availability,
#          tref: tref
#      }}
#   end

#   def handle_cast(:clear_alarm, state), do: {:noreply, %{state | raised_deployment: false}}
#   def handle_cast(:set_alarm, state), do: {:noreply, %{state | raised_deployment: true}}

#   def terminate(_, _), do: :ok

#   #
#   # gen_event
#   #
#   def handle_call(_request, state), do: {:ok, :ok, state}

#   def handle_event({:clear_alarm, {:contract_deployment_issue, %{reporter: __MODULE__}}}, state) do
#     _ = Logger.info("Health check established connection to the client. :ethereum_client_connection alarm clearead.")
#     :ok = GenServer.cast(__MODULE__, :clear_alarm)
#     {:ok, state}
#   end

#   def handle_event({:set_alarm, {:contract_deployment_issue, %{reporter: __MODULE__}}}, state) do
#     _ = Logger.warn("Health check raised :ethereum_client_connection alarm.")
#     :ok = GenServer.cast(__MODULE__, :set_alarm)
#     {:ok, state}
#   end

#   # flush
#   def handle_event(event, state) do
#     _ = Logger.info("Eth client monitor got event: #{inspect(event)}. Ignoring.")
#     {:ok, state}
#   end

#   @spec check ::
#           {{:ok, pos_integer() | any()}
#            | {:ok | {:error, :root_chain_contract_not_available | :root_chain_authority_is_nil}}}
#   defp check do
#     height = do_height_check()
#     availability = do_contract_availability_check()
#     {height, availability}
#   end

#   defp do_height_check, do: eth().get_root_deployment_height()

#   defp do_contract_availability_check, do: eth().contract_ready

#   # negating validation because we translate them into alarm states
#   defp validate({height, availability}) do
#     {height, not is_number(height), availability, not (availability == :ok)}
#   end

#   defp eth, do: Application.get_env(:omg, :eth_integration_module, Eth)

#   defp install do
#     case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
#       true -> :ok
#       _ -> :alarm_handler.add_alarm_handler(__MODULE__)
#     end
#   end

#   @spec raise_clear(module(), boolean(), :error | non_neg_integer()) :: :ok | :duplicate
#   defp raise_clear(_alarm_module, true, :error), do: :ok

#   defp raise_clear(alarm_module, false, :error),
#     do: alarm_module.set({:ethereum_client_connection, Node.self(), __MODULE__})

#   defp raise_clear(alarm_module, true, _),
#     do: alarm_module.clear({:ethereum_client_connection, Node.self(), __MODULE__})

#   defp raise_clear(_alarm_module, false, _), do: :ok
# end
