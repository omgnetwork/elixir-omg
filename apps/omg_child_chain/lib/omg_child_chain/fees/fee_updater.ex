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
defmodule OMG.ChildChain.Fees.FeeUpdater do
  @moduledoc """
  Decides whether fees will be updated from the actual reading from feed.
  """

  alias OMG.ChildChain.Fees.FeeMerger
  alias OMG.Fees

  @type feed_reading_t :: {pos_integer(), Fees.full_fee_t()}
  @type can_update_result_t :: {:ok, feed_reading_t()} | :no_changes

  @doc """
  Newly fetched fees will be effective as long as the amount change on any token is significant
  or the time passed from previous update exceeds the update interval.
  """
  @spec can_update(
          stored :: feed_reading_t(),
          actual :: feed_reading_t(),
          tolerance_percent :: pos_integer(),
          update_interval_seconds :: pos_integer()
        ) :: can_update_result_t()
  def can_update({_, fee_spec}, {_, fee_spec}, _tolerance_percent, _update_interval_seconds), do: :no_changes

  def can_update({t0, _}, {t1, _} = updated, _tolerance_percent, update_interval_seconds)
      when t0 <= t1 and t1 - t0 >= update_interval_seconds,
      do: {:ok, updated}

  def can_update({_, stored}, {_, actual} = updated, tolerance_percent, _update_interval_seconds) do
    with merged when is_map(merged) <- merge_types(stored, actual),
         false <- Enum.any?(merged, &token_mismatch?/1),
         amount_diffs = Map.values(FeeMerger.merge_specs(stored, actual)),
         false <- is_change_significant?(amount_diffs, tolerance_percent) do
      :no_changes
    else
      _ -> {:ok, updated}
    end
  end

  # Change is significant when
  #  - token amount difference exceeds the tolerance level,
  #  - there is missing token in any of specs, so token support was either added or removed
  #    in the update.
  @spec is_change_significant?(list(Fees.merged_fee_t()), non_neg_integer()) :: boolean()
  defp is_change_significant?(token_amounts, tolerance_percent) do
    tolerance_rate = tolerance_percent / 100

    token_amounts
    |> Enum.flat_map(&Map.values/1)
    |> Enum.any?(&amount_diff_exceeds_tolerance?(&1, tolerance_rate))
  end

  # Checks whether previous and actual fees differenciate on token
  @spec token_mismatch?({non_neg_integer(), {Fees.fee_t(), Fees.fee_t()}}) :: boolean()
  defp token_mismatch?({_type, {stored_fees, actual_fees}}) do
    not MapSet.equal?(
      stored_fees |> Map.keys() |> MapSet.new(),
      actual_fees |> Map.keys() |> MapSet.new()
    )
  end

  @spec merge_types(Fees.full_fee_t(), Fees.full_fee_t()) ::
          %{non_neg_integer() => {Fees.fee_t(), Fees.fee_t()}} | :disjoint_types
  defp merge_types(stored_specs, actual_specs) do
    merged_spec = Map.merge(stored_specs, actual_specs, fn _t, stored, actual -> {stored, actual} end)

    merged_spec
    |> Map.values()
    |> Enum.all?(&Kernel.is_tuple/1)
    |> if(do: merged_spec, else: :disjoint_types)
  end

  defp amount_diff_exceeds_tolerance?([_no_change], _rate), do: false

  defp amount_diff_exceeds_tolerance?([prev, curr], rate) do
    abs(prev - curr) / prev >= rate
  end
end
