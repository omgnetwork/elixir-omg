defmodule LoadTest.TestCase do
  @callback run(Keyword.t()) :: %{status: :ok} | %{status: :error, type: atom()}
end
