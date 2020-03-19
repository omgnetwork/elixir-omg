defmodule Engine do
  @moduledoc """
  Documentation for Engine.
  """

  alias Engine.Transaction
  alias Engine.Repo

  @doc """
  Hello world.

  ## Examples

      iex> Engine.hello()
      :world

  """
  def hello do
    :world
  end

  @doc """
  Submits a transaction to the Engine.
  """
  #def submit(tx_bytes) do
    #changeset = Transaction.changeset(%Transaction{}, tx_bytes)
    #Repo.insert(changeset)
  #end
end
