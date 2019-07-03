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

defmodule Status.Metric.Measurements do
  @moduledoc """
    gathers metrics VM and sends them as telemetry event
  """
  def process,
    do:
      :telemetry.execute(
        [:vm, :process],
        %{
          count: :erlang.system_info(:process_count),
          limit: :erlang.system_info(:process_limit)
        },
        %{}
      )

  def port,
    do:
      :telemetry.execute(
        [:vm, :port],
        %{
          count: :erlang.system_info(:port_count),
          limit: :erlang.system_info(:port_limit)
        },
        %{}
      )

  def vm do
    :telemetry.execute(
      [:vm],
      %{
        # last_value
        atom_count: :erlang.system_info(:atom_count),
        modules: length(:code.all_loaded()),
        run_queue: :erlang.statistics(:run_queue),
        messages_in_queues:
          Enum.reduce(:erlang.processes(), 0, fn pid, acc ->
            case :erlang.process_info(pid, :message_queue_len) do
              :undefined -> acc
              {:message_queue_len, count} -> count + acc
            end
          end),
        # counter
        reductions: :erlang.statistics(:reductions) |> elem(1)
      },
      %{}
    )
  end

  def io do
    {{:input, input}, {:output, output}} = :erlang.statistics(:io)
    prev_input = Storage.exchange(:input, input)
    prev_output = Storage.exchange(:outpu, output)

    :telemetry.execute(
      [:vm, :io],
      %{
        bytes_in: input - prev_input,
        bytes_out: output - prev_output
      },
      %{}
    )
  end

  def gc do
    {gc_s, words, _} = :erlang.statistics(:garbage_collection)
    prev_gc_s = Storage.exchange(:gc_s, gc_s)
    prev_words = Storage.exchange(:words, words)

    :telemetry.execute(
      [:vm, :gc],
      %{
        count: gc_s - prev_gc_s,
        words_reclaimed: words - prev_words
      },
      %{}
    )
  end

  def scheduler_wall_time do
    case :erlang.statistics(:scheduler_wall_time) do
      :undefined ->
        :ok

      scheduler_wall_time ->
        scheduler_wall_time
        |> Enum.map(fn {scheduler_id, active, total} ->
          active_atom = ("active" <> Integer.to_string(scheduler_id)) |> String.to_atom()
          total_atom = ("total" <> Integer.to_string(scheduler_id)) |> String.to_atom()
          prev_active = Storage.exchange(active_atom, active)
          prev_total = Storage.exchange(total_atom, total)

          :telemetry.execute(
            [:vm, :scheduler_wall_time],
            %{
              active: active - prev_active,
              total: total - prev_total
            },
            %{scheduler_id: scheduler_id}
          )
        end)
    end
  end

  def all do
    process()
    port()
    vm()
    io()
    gc()
    scheduler_wall_time()
  end
end
