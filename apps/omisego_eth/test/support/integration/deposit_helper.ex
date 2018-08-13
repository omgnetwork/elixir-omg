defmodule OmiseGO.Eth.Integration.DepositHelper do
  @moduledoc """
  Common helper functions that are useful when integration-testing the child chain and watcher requiring deposits
  """

  alias OmiseGO.API.Crypto
  alias OmiseGO.Eth

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
    _ = Eth.DevHelpers.token_mint(to, value, token.address)

    {:ok, false} = Eth.DevHelpers.has_token(token.address)
    _ = Eth.DevHelpers.add_token(token.address)
    {:ok, true} = Eth.DevHelpers.has_token(token.address)

    contract_addr = Application.fetch_env!(:omisego_eth, :contract_addr)

    Eth.DevHelpers.token_approve(to, contract_addr, value, token.address)

    {:ok, receipt} = Eth.DevHelpers.deposit_token(to, token.address, value)

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
end
