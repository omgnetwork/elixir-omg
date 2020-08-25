defmodule LoadTest.ChildChain.Exit do
  @moduledoc """
  Utility functions for exits on a child chain.
  """

  require Logger

  alias ExPlasma.Encoding
  alias LoadTest.ChildChain.Transaction
  alias LoadTest.Ethereum
  alias LoadTest.Ethereum.Crypto

  @gas_start_exit 400_000
  @gas_challenge_exit 300_000
  @gas_add_exit_queue 800_000
  @standard_exit_bond 14_000_000_000_000_000
  @token <<0::160>>
  @vault_id 1

  def start_exit(utxo_pos, tx_bytes, proof, from) do
    opts =
      tx_defaults()
      |> Keyword.put(:gas, @gas_start_exit)
      |> Keyword.put(:value, @standard_exit_bond)

    {:ok, transaction_hash} =
      Ethereum.contract_transact(
        from,
        contract_address_payment_exit_game(),
        "startStandardExit((uint256,bytes,bytes))",
        [{utxo_pos, tx_bytes, proof}],
        opts
      )

    Encoding.to_hex(transaction_hash)
  end

  def add_exit_queue() do
    if has_exit_queue?() do
      _ = Logger.info("Exit queue was already added.")
    else
      _ = Logger.info("Exit queue missing. Adding...")

      {:ok, [faucet | _]} = Ethereumex.HttpClient.eth_accounts()

      data =
        ABI.encode(
          "addExitQueue(uint256,address)",
          [@vault_id, @token]
        )

      txmap = %{
        from: faucet,
        to: Application.fetch_env!(:load_test, :contract_address_plasma_framework),
        value: Encoding.to_hex(0),
        data: Encoding.to_hex(data),
        gas: Encoding.to_hex(@gas_add_exit_queue)
      }

      {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap) |> IO.inspect()
      Ethereum.transact_sync(receipt_hash) |> IO.inspect()
      wait_for_exit_queue(100)
      receipt_hash
    end
  end

  defp wait_for_exit_queue(0), do: exit(1)

  defp wait_for_exit_queue(counter) do
    if has_exit_queue?() do
      :ok
    else
      Process.sleep(1_000)
      wait_for_exit_queue(counter - 1)
    end
  end

  defp has_exit_queue?() do
    data =
      ABI.encode(
        "hasExitQueue(uint256,address)",
        [@vault_id, @token]
      )

    {:ok, receipt_enc} =
      Ethereumex.HttpClient.eth_call(%{
        to: Application.fetch_env!(:load_test, :contract_address_plasma_framework),
        data: Encoding.to_hex(data)
      })

    receipt_enc
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([:bool])
    |> hd()
  end

  def challenge_exit(exit_id, exiting_tx, challenge_tx, input_index, challenge_tx_sig, from) do
    opts = Keyword.put(tx_defaults(), :gas, @gas_challenge_exit)
    sender_data = Crypto.hash(from)

    contract = contract_address_payment_exit_game()
    signature = "challengeStandardExit((uint160,bytes,bytes,uint16,bytes,bytes32))"
    args = [{exit_id, exiting_tx, challenge_tx, input_index, challenge_tx_sig, sender_data}]

    {:ok, transaction_hash} = Ethereum.contract_transact(from, contract, signature, args, opts)

    Encoding.to_hex(transaction_hash)
  end

  def tx_defaults() do
    Transaction.tx_defaults()
  end

  defp contract_address_payment_exit_game() do
    :load_test
    |> Application.fetch_env!(:contract_address_payment_exit_game)
    |> IO.inspect()
    |> Encoding.to_binary()
  end
end
