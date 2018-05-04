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

  def eth_receipt(txhash, timeout \\ 15_000) do
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
end
