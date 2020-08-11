defmodule LoadTest.ChildChain.Exit do
  @moduledoc """
  Utility functions for exits on a child chain.
  """

  alias ExPlasma.Encoding
  alias LoadTest.Ethereum
  alias LoadTest.Ethereum.Crypto

  # safe, reasonable amount, equal to the testnet block gas limit
  @lots_of_gas 5_712_388
  @gas_price 1_000_000_000
  @gas_start_exit 400_000
  @gas_challenge_exit 300_000
  @standard_exit_bond 14_000_000_000_000_000

  def start_exit(utxo_pos, tx_bytes, proof, from) do
    opts =
      tx_defaults()
      |> Keyword.put(:gas, @gas_start_exit)
      |> Keyword.put(:value, @standard_exit_bond)

    Ethereum.contract_transact(
      from,
      contract_address_payment_exit_game(),
      "startStandardExit((uint256,bytes,bytes))",
      [{utxo_pos, tx_bytes, proof}],
      opts
    )
  end

  def challenge_exit(exit_id, exiting_tx, challenge_tx, input_index, challenge_tx_sig, from) do
    opts = Keyword.put(@tx_defaults, :gas, @gas_challenge_exit)
    sender_data = Crypto.hash(from)

    contract = contract_address_payment_exit_game()
    signature = "challengeStandardExit((uint160,bytes,bytes,uint16,bytes,bytes32))"
    args = [{exit_id, exiting_tx, challenge_tx, input_index, challenge_tx_sig, sender_data}]

    Ethereum.contract_transact(from, contract, signature, args, opts)
  end

  defp tx_defaults() do
    Enum.map([value: 0, gasPrice: @gas_price, gas: @lots_of_gas], fn {k, v} -> {k, Encoding.to_hex(v)} end)
  end

  defp contract_address_payment_exit_game() do
    :load_test
    |> Application.fetch_env!(:contract_address_payment_exit_game)
    |> Encoding.from_hex()
  end
end
