defmodule OMG.Watcher.Web.Serializer.Error do
  @moduledoc """
  Serializes data into JSON response format.
  """

  @spec serialize(String.t(), String.t()) :: %{code: String.t(), description: String.t()}
  def serialize(code, description) do
    %{
      code: code,
      description: description,
    }
  end

end
