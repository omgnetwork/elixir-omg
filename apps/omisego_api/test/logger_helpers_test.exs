defmodule OmiseGO.API.LoggerHelpersTests do
  @moduledoc false

  use ExUnit.Case, async: true

  import OmiseGO.API.LoggerHelpers

  @moduletag :logger

  test "result from fn - logging success result" do
    assert [">resulted with ", "':ok'"] == log_result({:ok}).()
    assert [">resulted with ", "':ok'"] == log_result({:ok, [1, 2, 3]}).()
    assert [">resulted with ", "':ok'"] == log_result({:ok, %{blknum: 1000, txindex: 2}}).()
  end

  test "result from fn - logging success result with fields" do
    data = %{blknum: 1000, txindex: 112, txhash: <<0::size(256)>>}

    assert [
             ">resulted with ",
             "':ok'",
             ?\n,
             ?\t,
             "blknum",
             ?\s,
             ?',
             "1000",
             ?',
             ?\n,
             ?\t,
             "txindex",
             ?\s,
             ?',
             "112",
             ?'
           ] == log_result({:ok, data}, [:blknum, :txindex]).()

    assert [
             ">resulted with ",
             "':ok'",
             ?\n,
             ?\t,
             "txhash",
             ?\s,
             ?',
             "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
             ?'
           ] == log_result({:ok, data}, :txhash).()
  end

  test "result from fn - logging success result with missing fields" do
    data = %{blknum: 1000, txindex: 112, txhash: <<0::size(256)>>}

    assert [">resulted with ", "':ok'"] == log_result({:ok, data}, :missing).()
  end

  test "result from fn - logging success result with context" do
    result = {:ok, %{blknum: 1000, txindex: 112}}

    fn_log =
      result
      |> log_result()
      |> with_context(%{p1: "This is param value"})

    assert [
             ">resulted with ",
             "':ok'",
             ?\n,
             ?\t,
             "p1",
             ?\s,
             ?',
             "This is param value",
             ?'
           ] == fn_log.()

    fn_log =
      result
      |> log_result(:txindex)
      |> with_context(%{p3: {:ok, "other"}})

    assert [
             ">resulted with ",
             "':ok'",
             ?\n,
             ?\t,
             "txindex",
             ?\s,
             ?',
             "112",
             ?',
             ?\n,
             ?\t,
             "p3",
             ?\s,
             ?',
             "{:ok, \"other\"}",
             ?'
           ] == fn_log.()

    fn_log =
      result
      |> log_result([:txindex, :blknum])
      |> with_context(%{p1: 0, p0: nil})

    assert [
             ">resulted with ",
             "':ok'",
             ?\n,
             ?\t,
             "blknum",
             ?\s,
             ?',
             "1000",
             ?',
             ?\n,
             ?\t,
             "txindex",
             ?\s,
             ?',
             "112",
             ?',
             ?\n,
             ?\t,
             "p0",
             ?\s,
             ?',
             "nil",
             ?',
             ?\n,
             ?\t,
             "p1",
             ?\s,
             ?',
             "0",
             ?'
           ] == fn_log.()
  end

  test "result from fn - logging error result" do
    assert [">resulted with ", "'[:error, :not_found]'"] == log_result({:error, :not_found}).()
    assert [">resulted with ", "'[:error, {1130, :conerr}]'"] == log_result({:error, {1130, :conerr}}).()
  end
end
