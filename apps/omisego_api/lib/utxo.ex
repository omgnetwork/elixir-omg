defmodule OmiseGO.API.Utxo do
  @moduledoc false

  @doc """
  Inserts a representaion of an UTXO position, usable in guards. See Utxo.Position for handling of these entities
  """
  defmacro position(blknum, txindex, oindex) do
    quote do
      {:utxo_position, unquote(blknum), unquote(txindex), unquote(oindex)}
    end
  end
end
