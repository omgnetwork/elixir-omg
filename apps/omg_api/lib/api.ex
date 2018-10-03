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

defmodule OMG.API do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain API.

  Should handle all the initial processing of requests like state-less validity, decoding/encoding
  (but not transport-specific encoding like hex).
  """

  alias OMG.API.{Core, FeeChecker, FreshBlocks, State}
  use OMG.JSONRPC.ExposeSpec
  use OMG.API.LoggerExt

  @spec submit(transaction :: bitstring) ::
          {:ok, %{tx_hash: bitstring, blknum: integer, tx_index: integer}} | {:error, atom}
  @expose_spec {:submit,
                %{
                  args: [transaction: :bitstring],
                  arity: 1,
                  name: :submit,
                  returns:
                    {:alternative,
                     [
                       ok: {:map, [tx_hash: :bitstring, blknum: :integer, tx_index: :integer]},
                       error: :atom
                     ]}
                }}
  def submit(transaction) do
    result =
      with {:ok, recovered_tx} <- Core.recover_tx(transaction),
           {:ok, fees} <- FeeChecker.transaction_fees(recovered_tx),
           {:ok, {tx_hash, blknum, tx_index}} <- State.exec(recovered_tx, fees) do
        {:ok, %{tx_hash: tx_hash, blknum: blknum, tx_index: tx_index}}
      end

    _ = Logger.debug(fn -> " resulted with #{inspect(result)}" end)

    result
  end

  @spec get_block(hash :: bitstring) ::
          {:ok, %{hash: bitstring, transactions: list, number: integer}} | {:error, :not_found | :internal_error}
  @expose_spec {:get_block,
                %{
                  args: [hash: :bitstring],
                  arity: 1,
                  name: :get_block,
                  returns:
                    {:alternative,
                     [
                       ok: {:map, [hash: :bitstring, transactions: :list, number: :integer]},
                       error: {:alternative, [:not_found, :internal_error]}
                     ]}
                }}
  def get_block(hash) do
    with {:ok, struct_block} <- FreshBlocks.get(hash) do
      _ = Logger.debug(fn -> " resulted successfully, hash '#{inspect(hash)}'" end)
      {:ok, Map.from_struct(struct_block)}
    else
      error ->
        _ = Logger.debug(fn -> " resulted with error #{inspect(error)}, hash '#{inspect(hash)}'" end)
        error
    end
  end
end
