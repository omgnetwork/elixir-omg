defmodule OmiseGO.Tracker do
  @moduledoc """
  Responsible for periodically checking if everything is ok, on all levels of Plasma consensus
  """

  ### Client

  def check_illegal_exits, do: :not_implemented

  def check_invalid_blocks, do: :not_implemented

  def check_block_withholding, do: :not_implemented

  def check_halting, do: :not_implemented

  ### Server

  use GenServer

  def init(:ok), do: :not_implemented

  def handle_call({:check_illegal_exits}, _from, _state) do
    # get parameters of what to check from state
    # get information from Eth (sidecause)
    # get information (utxos) from State (sidecause) ???
    # check
  end

  # TODO: rest similarly

  defmodule Core do
    @moduledoc """
    Functional core for the OmiseGO.Tracker
    """

    def initialize(_query_result, _height, _other?) do
      # figure out the state of the tracker where it's left off
    end

    def illegal_exits_query(_state) do

    end

    def check_illegal_exits(_query_result, _utxos, _state) do
      # decide whether all is ok
    end

    # TODO

  end

end
