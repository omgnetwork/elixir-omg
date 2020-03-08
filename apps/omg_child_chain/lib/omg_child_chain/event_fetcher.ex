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
defmodule OMG.ChildChain.EventFetcher do
  @moduledoc """
  This process combines all plasma contract events we're interested in and does eth_getLogs + enriches them if needed
  for all Ethereum Event Listener processes. 
  """
  use GenServer
  require Logger

  alias OMG.Eth.RootChain.Abi
  alias OMG.Eth.RootChain.Event
  alias OMG.Eth.RootChain.Rpc

  def deposit_created(server \\ __MODULE__, from_block, to_block) do
    GenServer.call(server, {:deposit_created, from_block, to_block})
  end

  def in_flight_exit_started(server \\ __MODULE__, from_block, to_block) do
    GenServer.call(server, {:in_flight_exit_started, from_block, to_block})
  end

  def in_flight_exit_piggybacked(server \\ __MODULE__, from_block, to_block) do
    # input and output
    GenServer.call(server, {:in_flight_exit_piggybacked, from_block, to_block})
  end

  def exit_started(server \\ __MODULE__, from_block, to_block) do
    GenServer.call(server, {:exit_started, from_block, to_block})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def init(opts) do
    contracts = opts |> Keyword.fetch!(:contracts) |> Map.values() |> Enum.map(&from_hex(&1))
    # events = [[signature: "ExitStarted(address,uint160)", name: :exit_started, enrich: true],..]
    events =
      opts
      |> Keyword.fetch!(:events)
      |> Enum.map(&Keyword.fetch!(&1, :name))
      |> Event.get_events()
      |> Enum.zip(Keyword.fetch!(opts, :events))
      |> Enum.reduce([], fn {signature, event}, acc -> [Keyword.put(event, :signature, signature) | acc] end)

    events_signatures =
      opts
      |> Keyword.fetch!(:events)
      |> Enum.map(&Keyword.fetch!(&1, :name))
      |> Event.get_events()

    ets_bucket = Keyword.fetch!(opts, :ets_bucket)
    rpc = Keyword.get(opts, :rpc, Rpc)
    # :ok = event_bus.subscribe("ethereum_new_height", link: true)

    {:ok,
     %{
       # 100 blocks of events will be kept in memory
       delete_events_treshold_height_blknum: 200,
       ets_bucket: ets_bucket,
       event_signatures: events_signatures,
       events: events,
       contracts: contracts,
       rpc: rpc
     }}
  end

  # I've  not quite convinced this is benefical for us in any way.
  # ETH listeners move at their own speed... But so is Event Fetcher.
  # Each ETH listner request is providing a range of eth blocks - and since
  # we gather events in bulk, they'll be here for other ETH listeners as well...
  #   def handle_info({:internal_event_bus, :ethereum_new_height, new_height_blknum}, state) do
  #     from_block = new_height_blknum
  #     to_block = new_height_blknum
  #     true = delete_old_logs(new_height_blknum, state)
  #     true = retrieve_and_store_logs(from_block, to_block, state)
  #     {:noreply, state}
  #   end

  def handle_call({:in_flight_exit_started, from_block, to_block}, _, state) do
    name = :in_flight_exit_started

    signature =
      state.events
      |> Enum.find(fn event -> Keyword.fetch!(event, :name) == name end)
      |> Keyword.fetch!(:signature)

    logs = handout_log(signature, from_block, to_block, state)

    {:reply, {:ok, logs}, state, {:continue, from_block}}
  end

  def handle_call({:in_flight_exit_piggybacked, from_block, to_block}, _, state) do
    names = [:in_flight_exit_output_piggybacked, :in_flight_exit_input_piggybacked]

    handout_logs =
      names
      |> Enum.reduce([], fn name, acc ->
        signature =
          state.events
          |> Enum.find(fn event -> Keyword.fetch!(event, :name) == name end)
          |> Keyword.fetch!(:signature)

        logs = handout_log(signature, from_block, to_block, state)
        [logs | acc]
      end)
      |> List.flatten()

    {:reply, {:ok, handout_logs}, state, {:continue, from_block}}
  end

  def handle_call({name, from_block, to_block}, _, state) do
    signature =
      state.events
      |> Enum.find(fn event -> Keyword.fetch!(event, :name) == name end)
      |> Keyword.fetch!(:signature)

    logs = handout_log(signature, from_block, to_block, state)
    {:reply, {:ok, logs}, state, {:continue, from_block}}
  end

  def handle_continue(new_height_blknum, state) do
    _ = delete_old_logs(new_height_blknum, state)
    {:noreply, state}
  end

  defp retrieve_and_store_logs(from_block, to_block, state) do
    from_block
    |> get_logs(to_block, state)
    |> enrich_logs(state)
    |> insert_logs(from_block, to_block, state)
  end

  defp get_logs(from_height, to_heigh, state) do
    {:ok, logs} = state.rpc.get_ethereum_events(from_height, to_heigh, state.event_signatures, state.contracts)
    Enum.map(logs, &Abi.decode_log(&1))
  end

  # we get the logs from RPC and we cross check with the event definition if we need to enrich them
  defp enrich_logs(decoded_logs, state) do
    events = state.events
    rpc = state.rpc

    Enum.map(decoded_logs, fn decoded_log ->
      decoded_log_signature = decoded_log.event_signature

      event = Enum.find(events, fn event -> Keyword.fetch!(event, :signature) == decoded_log_signature end)

      case Keyword.fetch!(event, :enrich) do
        true ->
          {:ok, enriched_data} = rpc.get_call_data(decoded_log.root_chain_txhash)

          enriched_data_decoded = enriched_data |> from_hex |> Abi.decode_function()
          Map.put(decoded_log, :call_data, enriched_data_decoded)

        _ ->
          decoded_log
      end
    end)
  end

  defp insert_logs(decoded_logs, from_block, to_block, state) do
    event_signatures = state.event_signatures

    # all logs come in a list of maps
    # we want to group them by blknum and signature:
    # [{286, "InFlightExitChallengeResponded(address,bytes32,uint256)", [event]},
    # {287, "ExitChallenged(uint256)",[event, event]]
    decoded_logs_in_keypair =
      decoded_logs
      |> Enum.group_by(
        fn decoded_log ->
          {decoded_log.eth_height, decoded_log.event_signature}
        end,
        fn decoded_log ->
          decoded_log
        end
      )
      |> Enum.map(fn {{blknum, signature}, logs} ->
        {blknum, signature, logs}
      end)

    # if we visited a particular range of blknum (from, to) we want to
    # insert empty data in the DB, so that clients know we've been there and that blocks are
    # empty of logs.
    # for the whole from, to range and signatures we create group pairs like so:
    # from = 286, to = 287 signatures = ["Exit", "Deposit"]
    # [{286, "Exit", []},{286, "Deposit", []},{287, "Exit", []},{287, "Deposit", []}]
    empty_blknum_signature_events =
      from_block..to_block
      |> Enum.to_list()
      |> Enum.map(fn blknum -> Enum.map(event_signatures, fn signature -> {blknum, signature, []} end) end)
      |> List.flatten()

    # we now merge the two lists
    # it is important that logs we got from RPC are first
    # because uniq_by takes the first occurance of {blknum, signature}
    # so that we don't overwrite retrieved logs
    data =
      decoded_logs_in_keypair
      |> Enum.concat(empty_blknum_signature_events)
      |> Enum.uniq_by(fn {blknum, signature, _data} ->
        {blknum, signature}
      end)

    :ets.insert(state.ets_bucket, data)
  end

  # delete everything older then (current block - delete_events_treshold)
  defp delete_old_logs(new_height_blknum, state) do
    # :ets.fun2ms(fn {block_number, _event_signature, _event} when
    # block_number <= new_height - delete_events_treshold -> true end)
    match_spec = [
      {{:"$1", :"$2", :"$3"},
       [{:"=<", :"$1", {:-, {:const, new_height_blknum}, {:const, state.delete_events_treshold_height_blknum}}}],
       [true]}
    ]

    :ets.select_delete(state.ets_bucket, match_spec)
  end

  # allow ethereum event listeners to retrieve logs from ETS in bulk
  defp handout_log(signature, from_block, to_block, state) do
    # :ets.fun2ms(fn {block_number, event_signature, event} when
    # block_number >= from_block and block_number <= to_block
    # and event_signature == signature -> event and
    # end)
    event_match_spec = [
      {{:"$1", :"$2", :"$3"},
       [
         {:andalso, {:andalso, {:>=, :"$1", {:const, from_block}}, {:"=<", :"$1", {:const, to_block}}},
          {:==, :"$2", {:const, signature}}}
       ], [:"$3"]}
    ]

    block_range = [
      {{:"$1", :"$2", :"$3"},
       [
         {:andalso, {:andalso, {:>=, :"$1", {:const, from_block}}, {:"=<", :"$1", {:const, to_block}}},
          {:==, :"$2", {:const, signature}}}
       ], [:"$1"]}
    ]

    events = state.ets_bucket |> :ets.select(event_match_spec) |> List.flatten()
    blknum_list = :ets.select(state.ets_bucket, block_range)

    # we may not have all the block information the ethereum event listener wants
    # so we check for that and find all logs for missing blocks
    # in one RPC call for all signatures
    case Enum.to_list(from_block..to_block) -- blknum_list do
      [] ->
        events

      missing_blocks ->
        missing_blocks = Enum.sort(missing_blocks)
        missing_from_block = List.first(missing_blocks)
        missing_to_block = List.last(missing_blocks)

        _ =
          Logger.info(
            "Missing block information (#{missing_from_block}, #{missing_to_block}) in event fetcher. Additional RPC call to gather logs."
          )

        true = retrieve_and_store_logs(missing_from_block, missing_to_block, state)
        handout_log(signature, from_block, to_block, state)
    end
  end

  defp from_hex("0x" <> encoded), do: Base.decode16!(encoded, case: :lower)
end
