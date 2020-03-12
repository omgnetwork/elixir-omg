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

defmodule OMG.ChildChain do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain server's API.

  Should handle all the initial processing of requests like state-less validity, decoding/encoding
  (but not transport-specific encoding like hex).
  """
  use OMG.Utils.LoggerExt

  alias OMG.Block
  alias OMG.ChildChain.FeeServer
  alias OMG.ChildChain.FreshBlocks
  alias OMG.ChildChain.Transaction.Metrics
  alias OMG.ChildChain.Transaction.Submitter
  alias OMG.Fees
  alias OMG.Fees.FeeFilter
  alias OMG.State.Transaction

  @spec submit(transaction :: binary, submitter :: Submitter) ::
          {:ok, %{txhash: Transaction.tx_hash(), blknum: pos_integer, txindex: non_neg_integer}}
          | {:error, Submitter.submit_error_t()}
  def submit(transaction, submitter \\ Submitter, metrics \\ Metrics) do
    try do
      result = submitter.submit(transaction)

      metrics.emit_transaction_submit_event(result)
    rescue
      error_data ->
        metrics.emit_transaction_submit_event({:error, %{error_data: error_data}})

        # TODO(PR) - what should be done here? -- particularly in the scope of this PR? don't
        # what to change error flow, but do want to send the event to DD, for that reason
        # propagating the error for now

        reraise(error_data, __STACKTRACE__)
    catch
      exception_data ->
        metrics.emit_transaction_submit_event({:error, %{exception_data: exception_data}})

        # TODO(PR) - what should be done here? -- particularly in the scope of this PR? don't
        # what to change exception flow, but do want to send the event to DD, for that reason
        # propagating the exception for now

        throw(exception_data)
    end
    |> result_with_logging()
  end

  @spec get_block(hash :: binary) ::
          {:ok, %{hash: binary, transactions: list, blknum: integer}} | {:error, :not_found | :internal_error}
  def get_block(hash) do
    with {:ok, struct_block} <- FreshBlocks.get(hash) do
      {:ok, Block.to_api_format(struct_block)}
    end
    |> result_with_logging()
  end

  @spec get_filtered_fees(list(pos_integer()), list(String.t()) | nil) ::
          {:ok, Fees.full_fee_t()} | {:error, :currency_fee_not_supported}
  def get_filtered_fees(tx_types, currencies) do
    with {:ok, fees} <- FeeServer.current_fees() do
      FeeFilter.filter(fees, tx_types, currencies)
    end
    |> result_with_logging()
  end

  defp result_with_logging(result) do
    _ = Logger.debug(" resulted with #{inspect(result)}")
    result
  end
end
