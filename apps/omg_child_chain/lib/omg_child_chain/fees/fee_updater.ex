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
  Decides whether fees will be updated from the fetched fees from the feed.
  """

  alias OMG.ChildChain.Fees.FeeMerger
  alias OMG.Fees

  @type feed_reading_t :: {pos_integer(), Fees.full_fee_t()}
  @type can_update_result_t :: {:ok, feed_reading_t()} | :no_changes

  # Internal data structure resulted from merge `stored_fees` and `fetched_fees` by tx type.
  # See `merge_specs_by_tx_type/2`
  @typep maybe_unpaired_fee_specs_merge_t :: %{non_neg_integer() => Fees.fee_t() | {Fees.fee_t(), Fees.fee_t()}}

  # As above but fully paired, which means `stored_fees` and `fetched_fees` support the same tx types
  @typep paired_fee_specs_merge_t :: %{non_neg_integer() => {Fees.fee_t(), Fees.fee_t()}}

  @doc """
  Newly fetched fees will be effective as long as the amount change on any token is significant
  or the time passed from previous update exceeds the update interval.
  """
  @spec can_update(
          stored_fees :: feed_reading_t(),
          fetched_fees :: feed_reading_t(),
          tolerance_percent :: pos_integer(),
          update_interval_seconds :: pos_integer()
        ) :: can_update_result_t()
  def can_update({_, fee_spec}, {_, fee_spec}, _tolerance_percent, _update_interval_seconds), do: :no_changes

  def can_update({t0, _}, {t1, _} = updated, _tolerance_percent, update_interval_seconds)
      when t0 <= t1 and t1 - t0 >= update_interval_seconds,
      do: {:ok, updated}

  def can_update({_, stored_fees}, {_, fetched_fees} = updated, tolerance_percent, _update_interval_seconds) do
    merged = merge_specs_by_tx_type(stored_fees, fetched_fees)

    with false <- stored_and_fetched_differs_on_tx_type?(merged),
         false <- stored_and_fetched_differs_on_token?(merged),
         amount_diffs = Map.values(FeeMerger.merge_specs(stored_fees, fetched_fees)),
         false <- is_change_significant?(amount_diffs, tolerance_percent) do
      :no_changes
    else
      _ -> {:ok, updated}
    end
  end

  @spec merge_specs_by_tx_type(Fees.full_fee_t(), Fees.full_fee_t()) :: maybe_unpaired_fee_specs_merge_t()
  defp merge_specs_by_tx_type(stored_specs, fetched_specs) do
    Map.merge(stored_specs, fetched_specs, fn _t, stored_fees, fetched_fees -> {stored_fees, fetched_fees} end)
  end

  # Tells whether each tx_type in stored fees has a corresponding fees in fetched
  # Returns `true` when there is a mismatch
  @spec stored_and_fetched_differs_on_tx_type?(maybe_unpaired_fee_specs_merge_t()) :: boolean()
  defp stored_and_fetched_differs_on_tx_type?(merged_specs) do
    merged_specs
    |> Map.values()
    |> Enum.all?(&Kernel.is_tuple/1)
    |> Kernel.not()
  end

  # Checks whether previously stored and fetched fees differs on token
  # Returns `true` when there is a mismatch
  @spec stored_and_fetched_differs_on_token?(paired_fee_specs_merge_t()) :: boolean()
  defp stored_and_fetched_differs_on_token?(merged_specs) do
    Enum.any?(merged_specs, &merge_pair_differs_on_token?/1)
  end

  @spec merge_pair_differs_on_token?({non_neg_integer(), {Fees.fee_t(), Fees.fee_t()}}) :: boolean()
  defp merge_pair_differs_on_token?({_type, {stored_fees, fetched_fees}}) do
    not MapSet.equal?(
      stored_fees |> Map.keys() |> MapSet.new(),
      fetched_fees |> Map.keys() |> MapSet.new()
    )
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

  defp amount_diff_exceeds_tolerance?([_no_change], _rate), do: false

  defp amount_diff_exceeds_tolerance?([stored, fetched], rate) do
    abs(stored - fetched) / stored >= rate
  end
end
