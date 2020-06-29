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

defmodule OMG.DB.Models.PaymentExitInfo do
  @moduledoc """
  DB model wrapper that is responsible for Payment (V1) Exit Info.
  """

  alias OMG.DB

  @instance_name OMG.DB.Instance.ExitProcessor

  @ten_seconds 10_000
  @one_minute 60_000

  def exit_info(utxo_pos, instance \\ @instance_name) do
    {:ok, data} = DB.batch_get(:exit_info, [utxo_pos], instance: instance)
    {:ok, hd(data)}
  end

  def exit_infos(utxo_pos_list, instance \\ @instance_name)
      when is_list(utxo_pos_list) do
    DB.batch_get(:exit_info, utxo_pos_list, instance: instance, timeout: @ten_seconds)
  end

  def all_exit_infos(instance \\ @instance_name) do
    DB.get_all_by_type(:exit_info, instance: instance, timeout: @one_minute)
  end

  def all_in_flight_exits_infos(instance \\ @instance_name) do
    DB.get_all_by_type(:in_flight_exit_info, instance: instance, timeout: @one_minute)
  end
end
