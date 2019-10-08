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

defmodule OMG.Eth.RootChainHelper do
  @moduledoc """
    Helper functions for RootChain.
  """

  alias OMG.Eth
  alias OMG.Eth.Config
  alias OMG.Eth.RootChain
  alias OMG.Eth.TransactionHelper

  import OMG.Eth.Encoding, only: [to_hex: 1, from_hex: 1]

  @tx_defaults Eth.Defaults.tx_defaults()

  @deposit_created_event_signature "DepositCreated(address,uint256,address,uint256)"
  @challenge_ife_func_signature "challengeInFlightExitNotCanonical(bytes,uint8,bytes,uint8,uint256,bytes,bytes)"
  @challenge_ife_input_spent "challengeInFlightExitInputSpent(bytes,uint8,bytes,uint8,bytes)"
  @challenge_ife_output_spent "challengeInFlightExitOutputSpent(bytes,uint256,bytes,bytes,uint8,bytes)"

  @type optional_addr_t() :: <<_::160>> | nil

  @gas_add_token 800_000
  @gas_start_exit 1_000_000
  @gas_challenge_exit 300_000
  @gas_deposit 180_000
  @gas_deposit_from 250_000
  @gas_init 1_000_000
  @gas_start_in_flight_exit 2_000_000
  @gas_respond_to_non_canonical_challenge 1_000_000
  @gas_challenge_in_flight_exit_not_canonical 1_000_000

  @standard_exit_bond 14_000_000_000_000_000
  @ife_bond 37_000_000_000_000_000
  @piggyback_bond 28_000_000_000_000_000

  @type in_flight_exit_piggybacked_event() :: %{owner: <<_::160>>, tx_hash: <<_::256>>, output_index: non_neg_integer}

  def start_exit(utxo_pos, tx_bytes, proof, from, contract \\ %{}, opts \\ []) do
    defaults =
      @tx_defaults
      |> Keyword.put(:gas, @gas_start_exit)
      |> Keyword.put(:value, @standard_exit_bond)

    opts = Keyword.merge(defaults, opts)

    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    # NOTE: hardcoded for now, we're speaking to a particular exit game so this is fixed
    output_guard_preimage = ""
    backend = Application.fetch_env!(:omg_eth, :eth_node)

    TransactionHelper.contract_transact(
      backend,
      from,
      contract,
      "startStandardExit((uint192,bytes,bytes,bytes))",
      [{utxo_pos, tx_bytes, output_guard_preimage, proof}],
      opts
    )
  end

  def piggyback_in_flight_exit(in_flight_tx, output_index, from, contract \\ %{}, opts \\ []) do
    defaults =
      @tx_defaults
      |> Keyword.put(:gas, 1_000_000)
      |> Keyword.put(:value, @piggyback_bond)

    opts = Keyword.merge(defaults, opts)
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    backend = Application.fetch_env!(:omg_eth, :eth_node)

    TransactionHelper.contract_transact(
      backend,
      from,
      contract,
      "piggybackInFlightExit(bytes,uint8)",
      [in_flight_tx, output_index],
      opts
    )
  end

  def deposit(tx_bytes, value, from, contract \\ %{}, opts \\ []) do
    defaults = @tx_defaults |> Keyword.put(:gas, @gas_deposit)

    opts =
      defaults
      |> Keyword.merge(opts)
      |> Keyword.put(:value, value)

    contract = Config.maybe_fetch_addr!(contract, :eth_vault)
    backend = Application.fetch_env!(:omg_eth, :eth_node)
    TransactionHelper.contract_transact(backend, from, contract, "deposit(bytes)", [tx_bytes], opts)
  end

  def deposit_from(tx, from, contract \\ %{}, opts \\ []) do
    defaults = @tx_defaults |> Keyword.put(:gas, @gas_deposit_from)
    opts = Keyword.merge(defaults, opts)

    contract = Config.maybe_fetch_addr!(contract, :erc20_vault)
    backend = Application.fetch_env!(:omg_eth, :eth_node)
    TransactionHelper.contract_transact(backend, from, contract, "deposit(bytes)", [tx], opts)
  end

  def add_token(token, contract \\ %{}, opts \\ []) do
    opts = @tx_defaults |> Keyword.put(:gas, @gas_add_token) |> Keyword.merge(opts)

    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    {:ok, [from | _]} = Ethereumex.HttpClient.eth_accounts()
    backend = Application.fetch_env!(:omg_eth, :eth_node)
    TransactionHelper.contract_transact(backend, from_hex(from), contract, "addToken(address)", [token], opts)
  end

  def challenge_exit(
        exit_id,
        exiting_tx,
        challenge_tx,
        input_index,
        challenge_tx_sig,
        from,
        contract \\ %{},
        opts \\ []
      ) do
    defaults = @tx_defaults |> Keyword.put(:gas, @gas_challenge_exit)
    opts = Keyword.merge(defaults, opts)

    # NOTE: hardcoded for now, we're speaking to a particular exit game so this is fixed
    optional_bytes = ""
    optional_uint = 0

    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)

    signature = "challengeStandardExit((uint160,bytes,bytes,uint16,bytes,bytes,bytes,uint256,bytes,bytes))"

    args = [
      {exit_id, exiting_tx, challenge_tx, input_index, challenge_tx_sig, optional_bytes, optional_bytes, optional_uint,
       optional_bytes, optional_bytes}
    ]

    backend = Application.fetch_env!(:omg_eth, :eth_node)
    TransactionHelper.contract_transact(backend, from, contract, signature, args, opts)
  end

  def init_authority(from \\ nil, contract \\ %{}, opts \\ []) do
    defaults = Keyword.put(@tx_defaults, :gas, @gas_init)
    opts = Keyword.merge(defaults, opts)

    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    from = from || from_hex(Application.fetch_env!(:omg_eth, :authority_addr))
    backend = Application.fetch_env!(:omg_eth, :eth_node)

    TransactionHelper.contract_transact(backend, from, contract, "initAuthority()", [], opts)
  end

  def in_flight_exit(
        in_flight_tx,
        input_txs,
        input_utxos_pos,
        input_txs_inclusion_proofs,
        in_flight_tx_sigs,
        from,
        contract \\ %{},
        opts \\ []
      ) do
    defaults =
      @tx_defaults
      |> Keyword.put(:value, @ife_bond)
      |> Keyword.put(:gas, @gas_start_in_flight_exit)

    opts = Keyword.merge(defaults, opts)
    # FIXME don't miss removing this
    # struct StartExitArgs {
    #     bytes inFlightTx;
    #     bytes[] inputTxs;
    #     uint256[] inputTxTypes;
    #     uint256[] inputUtxosPos;
    #     bytes[] outputGuardPreimagesForInputs;
    #     bytes[] inputTxsInclusionProofs;
    #     bytes[] inputTxsConfirmSigs;
    #     bytes[] inFlightTxWitnesses;
    #     bytes[] inputSpendingConditionOptionalArgs;
    # }

    # NOTE: hardcoded for now, we're speaking to a particular exit game so this is fixed
    optional_bytes_array = List.duplicate("", Enum.count(input_txs))
    # NOTE: this in particular will go away, since separate specification of input tx types isn't necessary
    # c.f.: https://github.com/omisego/plasma-contracts/issues/338
    input_tx_types = List.duplicate(1, Enum.count(input_txs))

    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "startInFlightExit((bytes,bytes[],uint256[],uint256[],bytes[],bytes[],bytes[],bytes[],bytes[]))"

    args = [
      {in_flight_tx, input_txs, input_tx_types, input_utxos_pos, optional_bytes_array, input_txs_inclusion_proofs,
       optional_bytes_array, in_flight_tx_sigs, optional_bytes_array}
    ]

    backend = Application.fetch_env!(:omg_eth, :eth_node)

    TransactionHelper.contract_transact(backend, from, contract, signature, args, opts)
  end

  def process_exits(token, top_exit_id, exits_to_process, from, contract \\ %{}, opts \\ []) do
    opts = @tx_defaults |> Keyword.merge(opts)

    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    signature = "processExits(address,uint160,uint256)"
    args = [token, top_exit_id, exits_to_process]
    backend = Application.fetch_env!(:omg_eth, :eth_node)

    TransactionHelper.contract_transact(backend, from, contract, signature, args, opts)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def challenge_in_flight_exit_not_canonical(
        in_flight_txbytes,
        in_flight_input_index,
        competing_txbytes,
        competing_input_index,
        competing_tx_pos,
        competing_proof,
        competing_sig,
        from,
        contract \\ %{},
        opts \\ []
      ) do
    defaults = @tx_defaults |> Keyword.put(:gas, @gas_challenge_in_flight_exit_not_canonical)
    opts = Keyword.merge(defaults, opts)

    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = @challenge_ife_func_signature

    args = [
      in_flight_txbytes,
      in_flight_input_index,
      competing_txbytes,
      competing_input_index,
      competing_tx_pos,
      competing_proof,
      competing_sig
    ]

    backend = Application.fetch_env!(:omg_eth, :eth_node)

    TransactionHelper.contract_transact(backend, from, contract, signature, args, opts)
  end

  def respond_to_non_canonical_challenge(
        in_flight_tx,
        in_flight_tx_pos,
        in_flight_tx_inclusion_proof,
        from,
        contract \\ %{},
        opts \\ []
      ) do
    defaults = @tx_defaults |> Keyword.put(:gas, @gas_respond_to_non_canonical_challenge)
    opts = Keyword.merge(defaults, opts)

    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "respondToNonCanonicalChallenge(bytes,uint256,bytes)"

    args = [in_flight_tx, in_flight_tx_pos, in_flight_tx_inclusion_proof]
    backend = Application.fetch_env!(:omg_eth, :eth_node)

    TransactionHelper.contract_transact(backend, from, contract, signature, args, opts)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def challenge_in_flight_exit_input_spent(
        in_flight_txbytes,
        in_flight_input_index,
        spending_txbytes,
        spending_tx_input_index,
        spending_tx_sig,
        from,
        contract \\ %{},
        opts \\ []
      ) do
    defaults = @tx_defaults
    opts = Keyword.merge(defaults, opts)

    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = @challenge_ife_input_spent

    args = [
      in_flight_txbytes,
      in_flight_input_index,
      spending_txbytes,
      spending_tx_input_index,
      spending_tx_sig
    ]

    backend = Application.fetch_env!(:omg_eth, :eth_node)

    TransactionHelper.contract_transact(backend, from, contract, signature, args, opts)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def challenge_in_flight_exit_output_spent(
        in_flight_txbytes,
        in_flight_output_pos,
        in_flight_tx_inclusion_proof,
        spending_txbytes,
        spending_tx_input_index,
        spending_tx_sig,
        from,
        contract \\ %{},
        opts \\ []
      ) do
    defaults = @tx_defaults
    opts = Keyword.merge(defaults, opts)

    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = @challenge_ife_output_spent

    args = [
      in_flight_txbytes,
      in_flight_output_pos,
      in_flight_tx_inclusion_proof,
      spending_txbytes,
      spending_tx_input_index,
      spending_tx_sig
    ]

    backend = Application.fetch_env!(:omg_eth, :eth_node)

    TransactionHelper.contract_transact(backend, from, contract, signature, args, opts)
  end

  def has_token(token, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    Eth.call_contract(contract, "hasToken(address)", [token], [:bool])
  end

  def deposit_blknum_from_receipt(%{"logs" => logs}) do
    topic =
      @deposit_created_event_signature
      |> ExthCrypto.Hash.hash(ExthCrypto.Hash.kec())
      |> to_hex()

    [%{blknum: deposit_blknum}] =
      logs
      |> Enum.filter(&(topic in &1["topics"]))
      |> Enum.map(&RootChain.decode_deposit/1)

    deposit_blknum
  end
end
