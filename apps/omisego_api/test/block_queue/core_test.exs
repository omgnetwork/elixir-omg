defmodule OmiseGO.API.BlockQueue.CoreTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import OmiseGO.API.BlockQueue.Core
  alias OmiseGO.Eth.BlockSubmission
  alias OmiseGO.API.BlockQueue.GasPriceAdjustmentStrategyParams, as: GasPriceParams

  @moduletag :blockqueue

  def hashes(blocks) do
    for block <- blocks, do: block.hash
  end

  def empty do
    {:ok, state} =
      new(
        mined_child_block_num: 0,
        known_hashes: [],
        top_mined_hash: <<0::256>>,
        parent_height: 1,
        child_block_interval: 1000,
        chain_start_parent_height: 1,
        submit_period: 1,
        finality_threshold: 12,
        gas_price_adj_params: %GasPriceParams{}
      )

    state
  end

  def make_chain(length) do
    {:dont_form_block, queue} =
      2..length
      |> Enum.reduce(empty(), fn hash, state ->
        {:do_form_block, state, _, _} = set_ethereum_height(state, hash)
        enqueue_block(state, hash)
      end)
      |> set_ethereum_height(length)

    queue
  end

  def recover(known_hashes, mined_child_block_num) do
    top_mined_hash = "#{inspect(trunc(mined_child_block_num / 1000))}"

    new(
      mined_child_block_num: mined_child_block_num,
      known_hashes: known_hashes,
      top_mined_hash: top_mined_hash,
      parent_height: 10,
      child_block_interval: 1000,
      chain_start_parent_height: 1,
      submit_period: 1,
      finality_threshold: 12,
      gas_price_adj_params: %GasPriceParams{}
    )
  end

  describe "Block queue." do
    test "Requests correct block range on initialization" do
      assert [] == child_block_nums_to_init_with(0)
      assert [] == child_block_nums_to_init_with(99)
      assert [1000] == child_block_nums_to_init_with(1000)
      assert [1000, 2000, 3000] == child_block_nums_to_init_with(3000)
    end

    test "Recovers after restart to proper mined height" do
      assert ["8", "9"] =
               ["5", "6", "7", "8", "9"]
               |> recover(7000)
               |> elem(1)
               |> get_blocks_to_submit()
               |> hashes()
    end

    test "Recovers properly for fresh world state" do
      {:ok, queue} =
        new(
          mined_child_block_num: 0,
          known_hashes: [],
          top_mined_hash: <<0::size(256)>>,
          parent_height: 10,
          child_block_interval: 1000,
          chain_start_parent_height: 1,
          submit_period: 1,
          finality_threshold: 12,
          gas_price_adj_params: %GasPriceParams{}
        )

      assert [] ==
               queue
               |> get_blocks_to_submit()
               |> hashes()
    end

    test "Won't recover if is contract is ahead of db" do
      assert {:error, :contract_ahead_of_db} =
               new(
                 mined_child_block_num: 0,
                 known_hashes: [],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 submit_period: 1,
                 finality_threshold: 12,
                 gas_price_adj_params: %GasPriceParams{}
               )
    end

    test "Won't recover if there is a mined hash absent in db" do
      assert {:error, :mined_hash_not_found_in_db} =
               new(
                 mined_child_block_num: 0,
                 known_hashes: [<<2::size(256)>>],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 submit_period: 1,
                 finality_threshold: 12,
                 gas_price_adj_params: %GasPriceParams{}
               )
    end

    test "Recovers after restart and is able to process more blocks" do
      assert ["8", "9", "10"] =
               ["5", "6", "7", "8", "9"]
               |> recover(7000)
               |> elem(1)
               |> enqueue_block("10")
               |> get_blocks_to_submit()
               |> hashes()
    end

    test "Recovery will fail if DB is corrupted" do
      assert {:error, :mined_hash_not_found_in_db} = recover(["5", "6"], 7000)
    end

    test "No submitBlock will be sent until properly initialized" do
      catch_error(get_blocks_to_submit(new()))
    end

    test "A new block is emitted ASAP" do
      assert ["2"] =
               empty()
               |> set_mined(1000)
               |> enqueue_block("2")
               |> get_blocks_to_submit()
               |> hashes()
    end

    @tag :basic
    test "Produced child block numbers to form are as expected" do
      assert {:dont_form_block, queue} =
               empty()
               |> set_mined(0)
               |> set_ethereum_height(1)

      assert {:do_form_block, _, 1000, 2000} =
               queue
               |> set_mined(0)
               |> set_ethereum_height(2)
    end

    test "Produced child blocks to form aren't repeated, if none are enqueued" do
      assert {:do_form_block, queue, 1000, 2000} =
               empty()
               |> set_ethereum_height(2)

      assert {:dont_form_block, _} =
               queue
               |> set_ethereum_height(3)
    end

    test "Ethereum updates and enqueues can go interleaved" do
      # no enqueue after set_ethereum_height(1) so don't form block
      assert {:dont_form_block, queue} =
               empty()
               |> set_ethereum_height(1)
               |> elem(1)
               |> set_ethereum_height(2)
               |> elem(1)
               |> set_ethereum_height(3)

      assert {:do_form_block, queue, 2000, 3000} =
               queue
               |> enqueue_block("1")
               |> set_ethereum_height(4)

      assert {:dont_form_block, queue} =
               queue
               |> set_ethereum_height(5)

      assert {:do_form_block, _queue, 3000, 4000} =
               queue
               |> enqueue_block("2")
               |> set_ethereum_height(6)
    end

    # NOTE: theoretically the back off is ver hard to get - testing if this rare occasion doesn't make the state weird
    test "Ethereum updates can back off and jump independent from enqueues" do
      # no enqueue after set_ethereum_height(2) so don't form block
      assert {:dont_form_block, queue} =
               empty()
               |> set_ethereum_height(1)
               |> elem(1)
               |> set_ethereum_height(2)
               |> elem(1)
               |> set_ethereum_height(1)

      assert {:do_form_block, queue, 2000, 3000} =
               queue
               |> enqueue_block("1")
               |> set_ethereum_height(3)

      assert {:dont_form_block, queue} =
               queue
               |> enqueue_block("2")
               |> set_ethereum_height(2)

      assert {:do_form_block, _queue, 3000, 4000} =
               queue
               |> set_ethereum_height(4)
    end

    test "Produced blocks submission requests have nonces in order" do
      assert [_, %{nonce: 2}] =
               empty()
               |> set_mined(0)
               |> enqueue_block("1")
               |> enqueue_block("2")
               |> get_blocks_to_submit()
    end

    test "Block generation is driven by Ethereum height" do
      assert {:dont_form_block, queue} =
               empty()
               |> set_mined(0)
               |> set_ethereum_height(1)

      assert {:dont_form_block, queue} =
               queue
               |> enqueue_block("1")
               |> set_ethereum_height(0)

      assert {:dont_form_block, queue} =
               queue
               |> set_ethereum_height(1)

      assert {:dont_form_block, queue} =
               queue
               |> set_ethereum_height(2)

      assert {:dont_form_block, _} =
               queue
               |> enqueue_block("2")
               |> set_ethereum_height(2)
    end

    test "Smoke test" do
      assert {:dont_form_block, queue} =
               empty()
               |> set_mined(0)
               |> enqueue_block("1")
               |> enqueue_block("2")
               |> enqueue_block("3")
               |> enqueue_block("4")
               |> enqueue_block("5")
               |> set_mined(2000)
               |> set_ethereum_height(3)

      assert ["3", "4", "5"] =
               queue
               |> get_blocks_to_submit()
               |> hashes()
    end

    test "Old blocks are GCd, but only after they're mined" do
      long_length = 10_000
      short_length = 100

      long = long_length |> make_chain()
      long_size = long |> :erlang.term_to_binary() |> byte_size()
      short_size = short_length |> make_chain() |> :erlang.term_to_binary() |> byte_size()

      # sanity check if we haven't GCd too early
      assert long_size > long_length / short_length * short_size

      long_mined_size =
        long |> set_mined((long_length - short_length) * 1000) |> :erlang.term_to_binary() |> byte_size()

      assert_in_delta(long_mined_size / short_size, 1, 0.2)
    end

    test "Pending tx can be resubmitted with new gas price" do
      {_, queue, _, _} =
        empty()
        |> set_mined(0)
        |> set_gas_price(1)
        |> enqueue_block("1")
        |> enqueue_block("2")
        |> set_ethereum_height(5)

      blocks = get_blocks_to_submit(queue)
      assert %BlockSubmission{gas_price: 1} = hd(blocks)

      blocks2 =
        queue
        |> set_gas_price(555)
        |> get_blocks_to_submit()

      assert %BlockSubmission{gas_price: 555} = hd(blocks2)
      assert length(blocks) == length(blocks2)
    end
  end

  defp state_with_gas_params(gas_params, keyword_list) do
    state = empty() |> Map.merge(keyword_list |> Map.new())
    %{state | gas_price_adj_params: gas_params}
  end

  describe "Adjusting gas price" do
    alias OmiseGO.API.BlockQueue.Core, as: State

    test "Lower gas price when eth blocks gap isn't filled. New gas price is rounded to closest integer" do
      lowering_factor = 0.5
      gas_price = 11
      expected = 6

      gas_params =
        %GasPriceParams{
          eth_gap_without_child_blocks: 3,
          gas_price_lowering_factor: lowering_factor}
        |> GasPriceParams.with(1, 1000)

      state =
        state_with_gas_params(
          gas_params,
          parent_height: 3,
          formed_child_block_num: 1000,
          mined_child_block_num: 1000
        )

      actual =
        state
        |> set_gas_price(gas_price)
        |> calculate_gas_price()

      assert actual == expected
    end

    test "Raise gas price when eth blocks gap is filled. New gas price is rounded to closest integer" do
      raising_factor = 3
      gas_price = 5.5
      expected = 17

      gas_params =
        %GasPriceParams{
          eth_gap_without_child_blocks: 2,
          gas_price_raising_factor: raising_factor}
        |> GasPriceParams.with(1, 1000)

      state =
        state_with_gas_params(
          gas_params,
          parent_height: 3,
          formed_child_block_num: 5000,
          mined_child_block_num: 1000
        )

      actual =
        state
        |> set_gas_price(gas_price)
        |> calculate_gas_price()

      assert actual == expected
    end

    test "Lower gas price when eth blocks gap is filled but blocks were mined since last check" do
      gas_price = 10

      gas_params = GasPriceParams.with(
        %GasPriceParams{
          eth_gap_without_child_blocks: 2},
          2,
          3000)

      state =
        state_with_gas_params(
          gas_params,
          parent_height: 6,
          formed_child_block_num: 5000,
          mined_child_block_num: 4000
        )

      actual =
        state
        |> set_gas_price(gas_price)
        |> calculate_gas_price()

      assert actual < gas_price
    end

    test "Aplling gas price calculation several times return correct result" do
      start_gas_price = 25
      gas_price_params = GasPriceParams.with(GasPriceParams.new(1.7, 0.7), 1, 1000)

      # raise by 1.7 then lower by 0.7
      expected = Kernel.round(0.7 * Kernel.round(1.7 * start_gas_price))

      state1 =
        state_with_gas_params(
          gas_price_params,
          parent_height: 5,
          formed_child_block_num: 4000,
          mined_child_block_num: 1000
        )

      dumped_gas_price =
        state1
        |> set_gas_price(start_gas_price)
        |> calculate_gas_price()

      assert dumped_gas_price > start_gas_price

      state2 =
        state_with_gas_params(
          GasPriceParams.with(gas_price_params, 5, 4000),
          parent_height: 6,
          formed_child_block_num: 7000,
          mined_child_block_num: 5000
        )

      final_price =
        state2
        |> set_gas_price(dumped_gas_price)
        |> calculate_gas_price()

      assert expected == final_price
    end

    test "adjust_gas_price won't change gas price params if eth height not set" do
      state = %State{empty() | parent_height: nil}

      newstate = state |> adjust_gas_price()

      assert match?(%State{parent_height: nil, gas_price_adj_params: %GasPriceParams{last_block_mined: nil}}, newstate)
    end

    test "adjust_gas_price initializes gas price params if not set before" do
      state = empty()
      expected = {state.parent_height, state.mined_child_block_num}

      newstate = state |> adjust_gas_price()

      assert match?(expected, newstate.gas_price_adj_params)
    end

    test "adjust_gas_price won't change gas price params if there is no new eth blocks" do
      state = %State{
        empty()
        | parent_height: 210,
          gas_price_adj_params: %GasPriceParams{last_block_mined: {210, 1000}}
      }

      newstate = state |> adjust_gas_price()

      assert state == newstate
    end

    test "adjust_gas_price adjusts gas price parameters into the state" do
      state = %State{empty() | parent_height: 210, gas_price_adj_params: %GasPriceParams{last_block_mined: {200, 1000}}}
      expected_gas_price = calculate_gas_price(state)

      newstate = state |> adjust_gas_price()

      assert expected_gas_price == newstate.gas_price_to_use
    end

    test "adjust_gas_price updates last checked information in the state" do
      state = %State{
        empty()
        | parent_height: 211,
          formed_child_block_num: 7000,
          mined_child_block_num: 5000,
          gas_price_adj_params: %GasPriceParams{last_block_mined: {210, 4000}}
      }

      newstate = state |> adjust_gas_price()

      assert state.gas_price_to_use > newstate.gas_price_to_use
      assert {211, 5000} == newstate.gas_price_adj_params.last_block_mined
    end
  end
end
