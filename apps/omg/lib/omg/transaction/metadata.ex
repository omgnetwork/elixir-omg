defmodule OMG.Transaction.Metadata do
  @type metadata() :: binary() | nil
  defmacro is_metadata(metadata) do
    quote do
      unquote(metadata) == nil or (is_binary(unquote(metadata)) and byte_size(unquote(metadata)) == 32)
    end
  end
end
