defmodule OmiseGOWatcher.Integration.TestHelper do
  @moduledoc """
  Common helper functions that are useful when integration-testing the watcher
  """

  alias OmiseGO.Eth
  import OmiseGOWatcher.TestHelper

  def deposit_to_child_chain(to, value, contract) do
    {:ok, destiny_enc} = Eth.DevHelpers.import_unlock_fund(to)
    {:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(value, destiny_enc, contract.contract_addr)
    {:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)
    deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)

    post_deposit_child_block =
      deposit_blknum - 1 +
        (Application.get_env(:omisego_api, :ethereum_event_block_finality_margin) + 1) *
          Application.get_env(:omisego_eth, :child_block_interval)

    {:ok, _} =
      Eth.DevHelpers.wait_for_current_child_block(post_deposit_child_block, true, 60_000, contract.contract_addr)

    deposit_blknum
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
