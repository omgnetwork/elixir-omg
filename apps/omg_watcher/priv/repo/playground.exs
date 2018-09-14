# Script for experimenting with the database. You can run it as:
#
# $> cd apps/omg_watcher
# $> iex -S mix run --no-start
# iex> c "priv/repo/playground.exs"
# iex> OMG.Watcher.Playground.go()
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     OMG.Watcher.DB.Repo.insert!(%OMG.Watcher.DB.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
defmodule OMG.Watcher.Playground do
  @moduledoc false

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.State.Transaction.{Recovered, Signed}
  alias OMG.API.Utxo
  alias OMG.Watcher.DB.EthEventDB
  alias OMG.Watcher.DB.Repo
  alias OMG.Watcher.DB.TransactionDB
  alias OMG.Watcher.DB.TxOutputDB

  import Ecto.Query

  @eth Crypto.zero_address()

  require Logger

  defp generate_entity do
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, addr} = Crypto.generate_address(pub)
    %{priv: priv, addr: addr}
  end

  defp ensure_all_started(app_list) do
    app_list
    |> Enum.reduce([], fn app, list ->
      {:ok, started_apps} = Application.ensure_all_started(app)
      list ++ started_apps
    end)
  end

  defp ensure_all_stoped(started_apps) do
    started_apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    :ok
  end

  defp setup do
    setup(Enum.any?(Application.started_applications(), &(elem(&1, 0) == :ecto)))
  end

  defp setup(true), do: []

  defp setup(false) do
    apps = ensure_all_started([:postgrex, :ecto])
    child = [Supervisor.Spec.supervisor(OMG.Watcher.DB.Repo, [])]
    {:ok, tree} = Supervisor.start_link(child, strategy: :one_for_one)

    {tree, apps}
  end

  defp teardown({tree, apps}) do
    Supervisor.stop(tree)
    ensure_all_stoped(apps)
  end

  ## Put your code here
  def go do
    Logger.warn("Hello in Playground")

    Logger.debug("Starting dependencies")
    all_apps = setup()

    alice = generate_entity()
    bob = generate_entity()

    utxo = %Utxo{
      owner: alice.addr,
      currency: @eth,
      amount: 3_618_502_788_666_131_106_986_593_281_521_497_120_414_687_020_801_267_626_233_049_500_247_285_301_247
    }

    {:ok, _} =
      EthEventDB.insert_deposit(
        <<0xDE, 0xAD, 0xBE, 0xEF, 0::224>>,
        1001,
        utxo
      )

    utxos = %{
      address: alice.addr,
      utxos: [
        %{
          blknum: 1001,
          txindex: 0,
          oindex: 0,
          currency: @eth,
          amount: utxo.amount
        }
      ]
    }

    to_spend = 196_159_429_230_833_773_869_868_419_475_239_575_503_198_607_639_501_078_528

    {:ok, raw_tx} = Transaction.create_from_utxos(utxos, %{address: bob.addr, amount: to_spend})
    signed_tx = raw_tx |> Transaction.sign(alice.priv, <<>>)
    {:ok, transaction} = Recovered.recover_from(signed_tx)

    result = TransactionDB.insert(transaction, 3000, 101, 20_990)

    txs_from_db = Repo.all(from(t in TransactionDB, preload: [:inputs, :outputs]))

    # Create next payment to bob using tx utxo
    [utxo] = TxOutputDB.get_utxos(alice.addr)

    utxos = %{
      address: alice.addr,
      utxos: [
        %{
          blknum: 3000,
          txindex: 101,
          oindex: utxo.creating_tx_oindex,
          currency: @eth,
          amount: utxo.amount
        }
      ]
    }

    to_spend = 333
    {:ok, raw_tx} = Transaction.create_from_utxos(utxos, %{address: bob.addr, amount: to_spend})
    signed_tx = raw_tx |> Transaction.sign(alice.priv, <<>>)
    {:ok, transaction} = Recovered.recover_from(signed_tx)
    result = TransactionDB.insert(transaction, 5000, 7, 21_009)

    bob_utxo = TxOutputDB.get_by_position(5000, 7, 0)

    # Clean up
    Logger.warn("Cleaning the playground")
    Process.sleep(500)
    # teardown(all_apps)
  end
end
