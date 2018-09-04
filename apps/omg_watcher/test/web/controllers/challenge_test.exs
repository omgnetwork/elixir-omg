defmodule OMG.Watcher.Web.Controller.ChallengeTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures

  alias OMG.Watcher.TestHelper
  alias OMG.API.Crypto
  alias OMG.API
  alias OMG.Watcher.TransactionDB

  @moduletag :integration

  @eth Crypto.zero_address()

  describe "Controller.ChallengeTest" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "/challenges endpoint returns proper response format", %{alice: alice} do
      TransactionDB.update_with(%{
        transactions: [
          API.TestHelper.create_recovered([{1, 1, 0, alice}], @eth, [{alice, 120}])
        ],
        number: 1
      })

      %{
        "data" => %{
          "cutxopos" => _cutxopos,
          "eutxoindex" => _eutxoindex,
          "proof" => _proof,
          "sigs" => _sigs,
          "txbytes" => _txbytes
        },
        "result" => "success"
      } = TestHelper.rest_call(:get, "/challenges", %{"blknum" => 1, "txindex" => 1, "oindex" => 0})
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "/challenges endpoint returns error for non existing utxo", %{alice: alice} do
      %{
        "data" => %{
          "code" => "challenge:invalid",
          "description" => "The challenge of particular exit is invalid because provided utxo is not spent"
        },
        "result" => "error"
      } = TestHelper.rest_call(:get, "/challenges", %{"blknum" => 1, "txindex" => 1, "oindex" => 0})
    end
  end
end
