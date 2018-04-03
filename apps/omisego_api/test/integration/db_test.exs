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
    {from, {txhash, contract_address}} = OmiseGO.Eth.TestHelpers.create_new_contract()

    %{
      address: contract_address,
      from: from,
      txhash: txhash
    }
  end

  deffixture root_chain_contract_config(geth, contract) do
    # prevent warnings
    :ok = geth

    Application.put_env(:omisego_eth, :contract, contract.address, persistent: true)
    Application.put_env(:omisego_eth, :omg_addr, contract.from, persistent: true)
    Application.put_env(:omisego_eth, :txhash_contract, contract.txhash, persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_eth)

    on_exit fn ->
      Application.put_env(:omisego_eth, :contract, "0x0")
      Application.put_env(:omisego_eth, :omg_addr, "0x0")
      Application.put_env(:omisego_eth, :txhash_contract, "0x0")
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

    :ok = OmiseGO.API.State.deposit(alice, 10)

    :ok = OmiseGO.API.submit(tx)

    # FIXME: should actuallly be called by the Eth-driven BlockQueue
    OmiseGO.API.State.form_block(2, 3)

    dat_hash = <<20, 9, 184, 82, 130, 252, 199, 222, 114, 107, 24, 253, 47, 120,
                 250, 1, 224, 25, 79, 194, 87, 231, 47, 71, 192, 53, 223, 149, 190, 183,
                 170, 215>>

    assert :not_found = OmiseGO.API.get_block(<<0::size(256)>>)
    assert %OmiseGO.API.Block{hash: ^dat_hash} = OmiseGO.API.get_block(dat_hash)

    # FIXME - should actually stop and start apps to check if persistence works fine
    assert {:ok, [
      %{{2, 0, 0} => %{amount: 7, owner: ^bob}},
      %{{2, 0, 1} => %{amount: 3, owner: ^alice}}
    ]} = DB.utxos()

    {:error, :utxo_not_found} = OmiseGO.API.submit(tx)

    OmiseGO.API.State.form_block(2, 3)
  end

end
