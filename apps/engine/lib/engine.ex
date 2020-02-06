defmodule Engine do
  @moduledoc """
  Documentation for Engine.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Engine.hello()
      :world

  """
  def hello do
    :world
  end

  def submit(tx_bytes) do
    tx_bytes
    |> Engine.Transaction.build()
    |> Engine.Repo.insert()
  end
end
