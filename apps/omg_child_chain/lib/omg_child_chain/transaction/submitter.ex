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

alias OMG.Fees
alias OMG.ChildChain.FeeServer
alias OMG.State
alias OMG.State.Transaction

defmodule OMG.ChildChain.Transaction.Submitter do
  @moduledoc """
  A module running all transaction validations and if valid, submitting the transaction.
  """
  @type submit_error_t() :: Transaction.Recovered.recover_tx_error() | State.exec_error() | :transaction_not_supported

  @callback submit(transaction :: binary) ::
              {:ok, %{txhash: Transaction.tx_hash(), blknum: pos_integer, txindex: non_neg_integer}}
              | {:error, submit_error_t()}
              | {:error, any()}

  # the default behavior
  def submit(transaction) do
    with {:ok, recovered_tx} <- Transaction.Recovered.recover_from(transaction),
         :ok <- is_supported(recovered_tx),
         {:ok, fees} <- FeeServer.accepted_fees(),
         fees = Fees.for_transaction(recovered_tx, fees),
         {:ok, {tx_hash, blknum, tx_index}} <- State.exec(recovered_tx, fees) do
      {:ok, %{txhash: tx_hash, blknum: blknum, txindex: tx_index}}
    else
      {:error, error_data} -> {:error, error_data}
    end
  end

  defp is_supported(%Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction.Fee{}}}),
    do: {:error, :transaction_not_supported}

  defp is_supported(%Transaction.Recovered{}), do: :ok
end
