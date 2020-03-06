defmodule LoadTest.Connection.Utils do
  @moduledoc """
  Utils functions that can be shared to all connection modules for Tesla clients
  """

  def retry?() do
    fn
      {:ok, %{status: status}} when status in 400..599 -> true
      {:ok, _} -> false
      {:error, _} -> true
    end
  end
end
