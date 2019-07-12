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

defmodule OMG.ChildChain do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain server's API.

  Should handle all the initial processing of requests like state-less validity, decoding/encoding
  (but not transport-specific encoding like hex).
  """

  alias OMG.Block
  alias OMG.ChildChain.FeeServer
  alias OMG.ChildChain.FreshBlocks
  alias OMG.Fees
  alias OMG.State
  alias OMG.State.Transaction
  use OMG.Utils.LoggerExt
  use OMG.Utils.Metrics

  @type submit_error() :: Transaction.Recovered.recover_tx_error() | State.exec_error()

  @decorate measure_event()
  @spec submit(transaction :: binary) ::
          {:ok, %{txhash: Transaction.tx_hash(), blknum: pos_integer, txindex: non_neg_integer}}
          | {:error, submit_error()}
  def submit(transaction) do
    # NOTE: ALD: `recover_from` does the "stateless" validity. This will need to dispatch based on tx type, after some
    # generic decoding. Note that this works in the process of the caller, e.g. `cowboy`
    #
    # Currently, it builds a single kind of Transaction struct
    # It also has the "authorization" part baked in - it only figures out the `spenders` that have authorized the `tx`
    # based on signatures. With this list `Transaction.Recovered.all_spenders_authorized/2` can figure out whether
    # a set of outputs given has been authorized to be spent (this is called somewhere in `OMG.State.exec`)
    #
    # 1st draft ALD: it could call into something like `CommonTransaction.decode`, `AbstractTransaction.reconstruct`
    # `AbstractWitnessedTransaction.get_authorization_keyring` (abstract version of `Transaction.Signed.get_spenders`)
    with {:ok, recovered_tx} <- Transaction.Recovered.recover_from(transaction),
         {:ok, fees} <- FeeServer.transaction_fees(),
          # NOTE: ALD: a particular transaction type needs to dispatch in here to figure out how much fees should a
          # particular txtype/tx pay.
          #
          # Currently, this returns the same `fee_spec` map for every transaction, or `:ignore` for merge txs which are
          # free
          #
          # 1st draft ALD: call into `AbstractTransaction.fees_for_tx` or similar
         fees = Fees.for_tx(recovered_tx, fees),
         # NOTE: ALD: stateful validity goes here
         # Currently it will:
         #   1/ get the input pointers (currently `utxo_pos`) and fetch the utxos spent from the state (UTXO set)
         #   2/ call `Transaction.Recovered.all_spenders_authorized/2`, knowning the owners of the inputs
         #   3/ check the main correctness predicate `sum(inputs)>=sum(outputs)`
         #   4/ somewhat redundantly (but thats ok), check fees `sum(inputs)>=sum(outputs) + fees_required`
         #   5/ apply the valid tx - removes some UTXOs from UTXO set, adds another
         #
         # Here is where the difference `output_id` vs `utxo_pos` would impact us the most
         #
         # 1st draft ALD: could call functions in `AbstractOutput` to perform the output-specific checks and operations
         {:ok, {tx_hash, blknum, tx_index}} <- State.exec(recovered_tx, fees) do
      {:ok, %{txhash: tx_hash, blknum: blknum, txindex: tx_index}}
    end
    |> result_with_logging()
  end

  @decorate measure_event()
  @spec get_block(hash :: binary) ::
          {:ok, %{hash: binary, transactions: list, blknum: integer}} | {:error, :not_found | :internal_error}
  def get_block(hash) do
    with {:ok, struct_block} <- FreshBlocks.get(hash) do
      {:ok, Block.to_api_format(struct_block)}
    end
    |> result_with_logging()
  end

  defp result_with_logging(result) do
    _ = Logger.debug(" resulted with #{inspect(result)}")
    result
  end
end
