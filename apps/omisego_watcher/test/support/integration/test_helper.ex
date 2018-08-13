defmodule OmiseGOWatcher.Integration.TestHelper do
  @moduledoc """
  Common helper functions that are useful when integration-testing the watcher
  """

  alias OmiseGO.Eth
  alias OmiseGO.API.Crypto

  import OmiseGOWatcher.TestHelper

  @eth Crypto.zero_address()

  def deposit_to_child_chain(to, value, token \\ @eth)

  def deposit_to_child_chain(to, value, @eth) do
    {:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(value, to)
    {:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)
    deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)

    wait_deposit_recognized(deposit_blknum)

    deposit_blknum
  end

  def deposit_to_child_chain(to, value, token) do
    _ = Eth.DevHelpers.token_mint(to, 10, token.address)

    {:ok, false} = Eth.DevHelpers.has_token(token.address)
    _ = Eth.DevHelpers.add_token(token.address)
    {:ok, true} = Eth.DevHelpers.has_token(token.address)

    contract_addr = Application.fetch_env!(:omisego_eth, :contract_addr)

    Eth.DevHelpers.token_approve(to, contract_addr, 10, token.address)

    {:ok, receipt} = Eth.DevHelpers.deposit_token(to, token.address, 10)

    token_deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)

    wait_deposit_recognized(token_deposit_blknum)

    token_deposit_blknum
  end

  defp wait_deposit_recognized(deposit_blknum) do
    post_deposit_child_block =
      deposit_blknum - 1 +
        (Application.get_env(:omisego_api, :ethereum_event_block_finality_margin) + 1) *
          Application.get_env(:omisego_eth, :child_block_interval)

    {:ok, _} = Eth.DevHelpers.wait_for_current_child_block(post_deposit_child_block, true, 60_000)

    # sleeping some more until when the deposit is spendable
    Process.sleep(Application.get_env(:omisego_api, :ethereum_event_get_deposits_interval_ms) * 2)

    :ok
  end

  def compose_utxo_exit(blknum, txindex, oindex) do
    decoded_resp = rest_call(:get, "account/utxo/compose_exit?blknum=#{blknum}&txindex=#{txindex}&oindex=#{oindex}")

    {:ok, txbytes} = Base.decode16(decoded_resp["txbytes"], case: :mixed)
    {:ok, proof} = Base.decode16(decoded_resp["proof"], case: :mixed)
    {:ok, sigs} = Base.decode16(decoded_resp["sigs"], case: :mixed)

    %{
      utxo_pos: decoded_resp["utxo_pos"],
      txbytes: txbytes,
      proof: proof,
      sigs: sigs
    }
  end

  def wait_until_block_getter_fetches_block(block_nr, timeout) do
    fn ->
      Eth.WaitFor.repeat_until_ok(wait_for_block(block_nr))
    end
    |> Task.async()
    |> Task.await(timeout)
  end

  defp wait_for_block(block_nr) do
    fn ->
      case GenServer.call(OmiseGOWatcher.BlockGetter, :get_height) < block_nr do
        true -> :repeat
        false -> {:ok, block_nr}
      end
    end
  end
end
