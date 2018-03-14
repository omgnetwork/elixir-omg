defmodule OmiseGO.DB do

  # Types-aware adapter to the db backend

  ### Client (port)

  def multi_update(_db_updates), do: :not_implemented

  def multi_get(_db_queries), do: :not_implemented

  def tx(_hash), do: :not_implemented

  @spec blocks(block_to_fetch :: list(integer)) :: map
  def blocks(_blocks_to_fetch) do
    %{}
  end

  def utxos, do: :not_implemented

  def height, do: :not_implemented

  defmodule Core do
    @moduledoc """
    Responsible for converting type-aware, logic-specific queries (updates) into backend specific queries (updates)
    """

    # adapter - testable, if we really really want to

    def parse_multi_update(_db_updates) do
      # parse
      _raw_updates = []
    end

    def blocks_query(_blocks_to_fetch) do
      # prepare
      _block_query = ""
    end

  end

end
