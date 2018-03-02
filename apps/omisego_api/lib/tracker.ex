defmodule OmiseGO.Tracker do
  @moduledoc """
  Responsible for periodically checking if everything is ok, on all levels of Plasma consensus
  """

  ### Client

  def check_illegal_exits()

  def check_invalid_blocks()

  def check_block_withholding()

  def check_halting()

  ### Server

  use GenServer

  def handle_call({:check_illegal_exits}, _from, state) do
    # get parameters of what to check from state
    # get information from Eth (sidecause)
    # get information (utxos) from State (sidecause) ???
    # check
  end

  # TODO: rest similarly

  defmodule Core do

    def initialize(query_result, height, etc...) do
      # figure out the state of the tracker where it's left off
    end

    def illegal_exits_query(state) do

    end

    def check_illegal_exits(query_result, utxos, state) do
      # decide whether all is ok
    end

    # TODO

  end

end
