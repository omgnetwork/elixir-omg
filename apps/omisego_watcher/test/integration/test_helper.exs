defmodule OmiseGOWatcher.Integration.TestHelper do
  alias OmiseGO.Eth
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.TestHelper, as: Test

  def deposit_to_child_chain(to, value, config) do
    {:ok, destiny_enc} = Eth.DevHelpers.import_unlock_fund(to)
    {:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(value, 0, destiny_enc, config.contract_addr)
    {:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)
    deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)

    post_deposit_child_block =
      deposit_blknum - 1 + (config.ethereum_event_block_finality_margin + 1) * config.child_block_interval

    {:ok, _} = Eth.DevHelpers.wait_for_current_child_block(post_deposit_child_block, true, 60_000, config.contract_addr)

    deposit_blknum
  end

  def compose_utxo_exit(block_height, txindex, oindex) do
    decoded_resp =
      Test.rest_call(:get, "account/utxo/compose_exit?block_height=#{block_height}&txindex=#{txindex}&oindex=#{oindex}")

    {:ok, tx_bytes} = Client.decode(:bitstring, decoded_resp["tx_bytes"])
    {:ok, proof} = Client.decode(:bitstring, decoded_resp["proof"])
    {:ok, sigs} = Client.decode(:bitstring, decoded_resp["sigs"])

    %{
      utxo_pos: decoded_resp["utxo_pos"],
      tx_bytes: tx_bytes,
      proof: proof,
      sigs: sigs
    }
  end

  def start_block_getter(config) do
    {:ok, _} =
      GenServer.start_link(
        OmiseGOWatcher.BlockGetter,
        %{contract_address: config.contract_addr},
        name: BlockGetter
      )
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
      case GenServer.call(BlockGetter, :get_height) < block_nr do
        true -> :repeat
        false -> {:ok, block_nr}
      end
    end
  end
end
