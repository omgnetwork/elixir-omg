defmodule OmiseGO.DB do

  # Types-aware adapter to the db backend

  ### Client (port)

  def multi_update(db_updates)

  def multi_get

  def tx(hash)

  def blocks(blocks_to_fetch)

  def utxos

  def height

  ### Server

  # TODO: only examples listed

  def handle_call({:multi_update, db_updates}, _from, nil) do
    # do all the listed updates in sequence
    # parse db updates in Core and process in db backend
  end

  def handle_call({:blocks, blocks_to_fetch}, _from, nil) do
    # prepare block query
    # execute low level query in db backend
  end

  defmodule Core do
    @moduledoc """
    Responsible for converting type-aware, logic-specific queries (updates) into backend specific queries (updates)
    """

    # adapter - testable, if we really really want to

    def parse_multi_update(db_updates) do
      # parse
      _raw_updates = []
    end

    def blocks_query(blocks_to_fetch) do
      # prepare
      _block_query = ""
    end

  end

end
