defmodule OmiseGO.API.LoggerHelpersTests do
@moduledoc false

  use ExUnit.Case, async: true

  import OmiseGO.API.LoggerHelpers

  @moduletag :logger

  test "result from fn - logging success result" do
    assert [">resulted with ", "':ok'"] == result_to_log({:ok}).()
    assert [">resulted with ", "':ok'"] == result_to_log({:ok, [1,2,3]}).()
    assert [">resulted with ", "':ok'"] == result_to_log({:ok, %{blknum: 1000, txindex: 2}}).()
  end

  test "result from fn - logging success result with fields" do
    data = %{blknum: 1000, txindex: 112, txhash: <<0::size(256)>>}

    assert [
      ">resulted with ", "':ok'",
      ?\n, ?\t, "blknum", ?\s, ?', "1000", ?',
      ?\n, ?\t, "txindex", ?\s, ?', "112", ?',
    ] == result_to_log({:ok, data}, [:blknum, :txindex]).()

    assert [
      ">resulted with ", "':ok'",
      ?\n,  ?\t, "txhash", ?\s, ?', "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", ?'
    ] == result_to_log({:ok, data}, :txhash).()
  end

  test "result from fn - logging success result with missing fields" do
    data = %{blknum: 1000, txindex: 112, txhash: <<0::size(256)>>}

    assert [">resulted with ", "':ok'"] == result_to_log({:ok, data}, :missing).()
  end

  test "result from fn - logging success result with context" do
    result = {:ok, %{blknum: 1000, txindex: 112}}

    fn_log = result
    |> result_to_log()
    |> with_context(%{p1: "This is param value"})

    assert [
      ">resulted with ", "':ok'",
      ?\n, ?\t, "p1", ?\s, ?', "This is param value", ?',
    ] == fn_log.()

    fn_log = result
    |> result_to_log(:txindex)
    |> with_context(%{p3: {:ok, "other"}})

    assert [
      ">resulted with ", "':ok'",
      ?\n, ?\t, "txindex", ?\s, ?', "112", ?',
      ?\n, ?\t, "p3", ?\s, ?', "{:ok, \"other\"}", ?',
    ] == fn_log.()

    fn_log = result
    |> result_to_log([:txindex, :blknum])
    |> with_context(%{p1: 0, p0: nil})

    assert [
      ">resulted with ", "':ok'",
      ?\n, ?\t, "blknum", ?\s, ?', "1000", ?',
      ?\n, ?\t, "txindex", ?\s, ?', "112", ?',
      ?\n, ?\t, "p0", ?\s, ?', "nil", ?',
      ?\n, ?\t, "p1", ?\s, ?', "0", ?',
    ] == fn_log.()
  end

  test "result from fn - logging error result" do
    assert [">resulted with ", "'[:error, :not_found]'"] == result_to_log({:error, :not_found}).()
    assert [">resulted with ", "'[:error, {1130, :conerr}]'"] == result_to_log({:error, {1130, :conerr}}).()
  end
end
