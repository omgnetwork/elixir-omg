# Copyright 2020 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.BlockQueue.BlockSubmission do
  @moduledoc """
  Handles block submission.
  """
  require Logger

  @type hash() :: <<_::256>>
  @type plasma_block_num() :: non_neg_integer()

  @type t() :: %__MODULE__{
          num: plasma_block_num(),
          hash: hash(),
          nonce: non_neg_integer(),
          gas_price: pos_integer()
        }
  defstruct [:num, :hash, :nonce, :gas_price]

  @type submit_result_t() :: {:ok, <<_::256>>} | {:error, map}

  @doc """
  Based on the result of a submission transaction returned from the Ethereum node, figures out what to do (namely:
  crash on or ignore an error response that is expected).

  It caters for the differences of those responses between Ethereum node RPC implementations.

  In general terms, those are the responses handled:
    - **known transaction** - this is common and expected to occur, since we are tracking submissions ourselves and
      liberally resubmitting same transactions; this is ignored
    - **low replacement price** - due to the gas price selection mechanism, there are cases where transaction will get
      resubmitted with a lower gas price; this is ignored
    - **account locked** - Ethereum node reports the authority account is locked; this causes a crash
    - **nonce too low** - there is an inherent race condition - when we're resubmitting a block, we do it with the same
      nonce, meanwhile it might happen that Ethereum mines this submission in this very instant; this is ignored if we
      indeed have just mined that submission, causes a crash otherwise
  """
  @spec process_result(t(), submit_result_t(), plasma_block_num()) ::
          {:ok, binary()} | :ok | {:error, atom}
  def process_result(submission, submit_result, newest_mined_blknum)

  def process_result(submission, {:ok, txhash}, _newest_mined_blknum) do
    log_success(submission, txhash)
    {:ok, txhash}
  end

  # https://github.com/ethereum/go-ethereum/commit/9938d954c8391682947682543cf9b52196507a88#diff-8fecce9bb4c486ebc22226cf681416e2
  def process_result(
        submission,
        {:error, %{"code" => -32_000, "message" => "already known"}},
        _newest_mined_blknum
      ) do
    log_known_tx(submission)
    :ok
  end

  # maybe this will get deprecated soon once the network migrates to 1.9.11.
  # Look at the previous function header for commit reference.
  # `fmt.Errorf("known transaction: %x", hash)`  has been removed
  def process_result(
        submission,
        {:error, %{"code" => -32_000, "message" => "known transaction" <> _}},
        _newest_mined_blknum
      ) do
    log_known_tx(submission)
    :ok
  end

  # parity error code for duplicated tx
  def process_result(
        submission,
        {:error, %{"code" => -32_010, "message" => "Transaction with the same hash was already imported."}},
        _newest_mined_blknum
      ) do
    log_known_tx(submission)
    :ok
  end

  def process_result(
        submission,
        {:error, %{"code" => -32_000, "message" => "replacement transaction underpriced"}},
        _newest_mined_blknum
      ) do
    log_low_replacement_price(submission)
    :ok
  end

  # parity version
  def process_result(
        submission,
        {:error, %{"code" => -32_010, "message" => "Transaction gas price is too low. There is another" <> _}},
        _newest_mined_blknum
      ) do
    log_low_replacement_price(submission)
    :ok
  end

  def process_result(
        submission,
        {:error, %{"code" => -32_000, "message" => "authentication needed: password or unlock"}},
        newest_mined_blknum
      ) do
    diagnostic = prepare_diagnostic(submission, newest_mined_blknum)
    log_locked(diagnostic)
    {:error, :account_locked}
  end

  def process_result(
        submission,
        {:error, %{"code" => -32_000, "message" => "nonce too low"}},
        newest_mined_blknum
      ) do
    process_nonce_too_low(submission, newest_mined_blknum)
  end

  # parity specific error for nonce-too-low
  def process_result(
        submission,
        {:error, %{"code" => -32_010, "message" => "Transaction nonce is too low." <> _}},
        newest_mined_blknum
      ) do
    process_nonce_too_low(submission, newest_mined_blknum)
  end

  # ganache has this error, but these are valid nonce_too_low errors, that just don't make any sense
  # `process_nonce_too_low/2` would mark it as a genuine failure and crash the BlockQueue :(
  # however, everything seems to just work regardless, things get retried and mined eventually
  # NOTE: we decide to degrade the severity to warn and continue, considering it's just `ganache`
  def process_result(
        _submission,
        {:error, %{"code" => -32_000, "data" => %{"stack" => "n: the tx doesn't have the correct nonce" <> _}}} = error,
        _newest_mined_blknum
      ) do
    log_ganache_nonce_too_low(error)
    :ok
  end

  defp log_ganache_nonce_too_low(error) do
    # runtime sanity check if we're actually running `ganache`, if we aren't and we're here, we must crash
    :ganache = Application.fetch_env!(:omg_eth, :eth_node)
    _ = Logger.warn(inspect(error))
    :ok
  end

  defp log_success(submission, txhash) do
    _ = Logger.info("Submitted #{inspect(submission)} at: #{inspect(txhash)}")
    :ok
  end

  defp log_known_tx(submission) do
    _ = Logger.debug("Submission #{inspect(submission)} is known transaction - ignored")
    :ok
  end

  defp log_low_replacement_price(submission) do
    _ = Logger.debug("Submission #{inspect(submission)} is known, but with higher price - ignored")
    :ok
  end

  defp log_locked(diagnostic) do
    _ = Logger.error("It seems that authority account is locked: #{inspect(diagnostic)}. Check README.md")
    :ok
  end

  defp process_nonce_too_low(%__MODULE__{num: blknum} = submission, newest_mined_blknum) do
    if blknum <= newest_mined_blknum do
      # apparently the `nonce too low` error is related to the submission having been mined while it was prepared
      :ok
    else
      diagnostic = prepare_diagnostic(submission, newest_mined_blknum)
      _ = Logger.error("Submission unexpectedly failed with nonce too low: #{inspect(diagnostic)}")
      {:error, :nonce_too_low}
    end
  end

  defp prepare_diagnostic(submission, newest_mined_blknum) do
    config = Application.get_all_env(:omg_eth) |> Keyword.take([:contract_addr, :authority_address, :txhash_contract])
    %{submission: submission, newest_mined_blknum: newest_mined_blknum, config: config}
  end
end
