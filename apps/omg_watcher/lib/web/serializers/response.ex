defmodule OMG.Watcher.Web.Serializer.Response do
  @moduledoc """
  Serializes data into response format.
  """

  @type response_result_t :: :success | :error

  @spec serialize(map(), response_result_t()) :: %{result: response_result_t(), data: map()}
  def serialize(data, result) do
    %{
      result: result,
      data: data
    }
  end

end
