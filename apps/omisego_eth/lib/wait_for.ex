defmodule OmiseGO.Eth.WaitFor do
  @moduledoc """
  Generic wait_for_* utils, styled after web3 counterparts
  """

  def eth_rpc do
    f = fn ->
      case Ethereumex.HttpClient.eth_syncing() do
        {:ok, false} -> {:ok, :ready}
        _ -> :repeat
      end
    end

    fn -> repeat_until_ok(f) end
    |> Task.async()
    |> Task.await(10_000)
  end

  def eth_receipt(txhash, timeout) do
    f = fn ->
      case Ethereumex.HttpClient.eth_get_transaction_receipt(txhash) do
        {:ok, receipt} when receipt != nil -> {:ok, receipt}
        _ -> :repeat
      end
    end

    fn -> repeat_until_ok(f) end
    |> Task.async()
    |> Task.await(timeout)
  end

  def eth_height(n, dev \\ false, timeout \\ 10_000) do
    f = fn() ->
      {:ok, height} = OmiseGO.Eth.get_ethereum_height
      case height < n do
        true ->
          _ = maybe_mine(dev)
          :repeat
        false ->
          {:ok, height}
      end
    end
    fn() -> repeat_until_ok(f) end
    |> Task.async |> Task.await(timeout)
  end

  def current_child_block(blknum, dev \\ false, timeout \\ 10_000) do
    f = fn() ->
      {:ok, next_num} = OmiseGO.Eth.get_current_child_block()
      case next_num < blknum do
        true ->
          _ = maybe_mine(dev)
          :repeat
        false ->
          {:ok, next_num}
      end
    end
    fn() -> repeat_until_ok(f) end
    |> Task.async |> Task.await(timeout)
  end

  # Repeats fun until fun returns {:ok, ...} OR exception is raised (see :erlang.exit, :erlang.error)
  # Simple throws and :badmatch are treated as signals to repeat
  def repeat_until_ok(f) do
    try do
      case f.() do
        {:ok, _} = return -> return
        _ -> repeat_until_ok(f)
      end
    catch
      _something ->
        Process.sleep(100)
        repeat_until_ok(f)

      :error, {:badmatch, _} = _error ->
        Process.sleep(100)
        repeat_until_ok(f)
    end
  end

  defp maybe_mine(false), do: :noop
  defp maybe_mine(true) do
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    txmap = %{from: addr, to: addr, value: "0x1"}
    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, _receipt} = eth_receipt(txhash, 1_000)
  end
end
