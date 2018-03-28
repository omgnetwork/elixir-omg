defmodule OmiseGO.API.Integration.DBTest do

  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OmiseGO.DB

  alias OmiseGO.API.TestHelper
  alias OmiseGO.API.State.Transaction

  # FIXME remove
  @moduletag :new

  deffixture db_path_config() do
    dir = Temp.mkdir!()

    Application.put_env(:omisego_db, :leveldb_path, dir, persistent: true)
    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)

    on_exit fn ->
      Application.put_env(:omisego_db, :leveldb_path, nil)
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  # FIXME: copied from eth/fixtures - DRY
  deffixture geth do
    {:ok, exit_fn} = OmiseGO.Eth.geth()
    on_exit(exit_fn)
    :ok
  end

  # FIXME: copied from eth/fixtures - DRY
  deffixture contract(geth) do
    _ = geth
    {from, contract_address} = OmiseGO.Eth.TestHelpers.create_new_contract()

    %{
      address: contract_address,
      from: from
    }
  end

  deffixture root_chain_contract_config(geth, contract) do
    # prevent warnings
    :ok = geth

    Application.put_env(:omisego_eth, :contract, contract.address, persistent: true)
    Application.put_env(:omisego_eth, :omg_addr, contract.from, persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_eth)

    on_exit fn ->
      Application.put_env(:omisego_eth, :contract, "0x0")
      Application.put_env(:omisego_eth, :omg_addr, "0x0")
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  deffixture omisego(root_chain_contract_config) do
    :ok = root_chain_contract_config
    {:ok, started_apps} = Application.ensure_all_started(:omisego_api)

    on_exit fn ->
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  @tag fixtures: [:db_path_config, :contract, :geth, :root_chain_contract_config, :omisego]
  test "saves state in DB", %{contract: root_chain} do

    alice = "Alice"
    bob = "Bob"

    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
      } |> TestHelper.signed

    tx = %Transaction.Recovered{signed: signed_tx, spender1: alice}

    {:error, :utxo_not_found} = OmiseGO.API.submit(tx)

    :ok = OmiseGO.API.State.deposit("Alice", 10)

    :ok = OmiseGO.API.submit(tx)

    {:error, :utxo_not_found} = OmiseGO.API.submit(tx)

    OmiseGO.API.State.form_block(2,3)
  end

end
