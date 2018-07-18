defmodule OmiseGO.API.LoggerHelpers do
@moduledoc """
Provides helper functions to support logging
"""

  require Logger

  @binary_max_length 500

  def result_to_log(result, fields \\ []) do
    fn ->
      [
        ">resulted with ",
        extract_result(result)
        | extract_fields(result, fields)
      ]
    end
  end

  def with_context(fn_log, %{} = context) do
    fn ->
      fn_log.() ++ extract_map(context)
    end
  end

  defp extract_result(result) when is_tuple(result), do: extract_result(Tuple.to_list(result))
  defp extract_result([:ok | _]), do: "':ok'"
  defp extract_result(error), do: "'#{inspect error}'"

  defp extract_fields({:ok, result}, fields) when is_map(result) do
    result
    |> Map.take(fields_to_list(fields))
    |> extract_map()
  end

  defp extract_fields(_, _fields), do: []

  defp extract_map(%{} = map) do
    map
    |> Enum.flat_map(fn {key, value} ->
        [?\n, ?\t, Atom.to_string(key), ?\s, ?', extract_value(value), ?']
      end)
  end

  defp extract_value(value) when is_binary(value) do
    value = if String.printable?(value),
      do: value,
      else: Base.encode64(IO.inspect value)

    String.slice(value, 0..@binary_max_length)
  end

  defp extract_value(value), do: "#{inspect value}"

  defp fields_to_list(field) when is_atom(field), do: [field]
  defp fields_to_list([a|_] = fields) when is_atom(a), do: fields
  defp fields_to_list(_), do: []
end
