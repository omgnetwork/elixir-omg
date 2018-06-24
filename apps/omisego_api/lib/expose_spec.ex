defmodule OmiseGO.API.ExposeSpec do
  @moduledoc """
  `use OmiseGO.API.ExposeSpec` to expose all @spec in the runtime via YourModule.get_specs()

  There is undocumented Kernel.Typespec.beam_specs/1 which exposes similar
  functionality. Unfortunately it is considered to be unstable.

  Avoid multiple arity functions
  # @spec arity(x :: integer, y :: integer) :: integer
  # def arity(x, y), do: x + y
  # @spec arity(x :: integer) :: integer
  # def arity(x), do: x + 2

  Avoid aliasing of types in specs - it will get silently dropped by AST parser
  # @spec aliased(x) :: x when x: integer
  # def aliased(x) do
  # x + 1
  # end

  NOTE: functions with the same name but different arity are not yet supported
  NOTE: spec AST parser is primitive, it does not handle all correct possibilities
  """

  @typedoc """
  Describes function: it's name, arity, list of arguments and their types, return type.
  """
  @type spec :: %{name: atom(), arity: arity(), args: [{atom(), type()}], returns: type()}
  @typedoc """
  Describes Elixir type. For details see https://hexdocs.pm/elixir/typespecs.html

  Note that tuple() denotes tuple of any size where all elements are of type type()
  """
  @type type() :: atom | tuple() | {:alternatives, [type()]}

  defp function_spec({:spec, {_, _, []}, _}) do
    :incomplete_spec
  end

  defp function_spec({:spec, {:::, _, body_return_pair}, _}) do
    body_ret_pair(body_return_pair)
  end

  defp function_spec({:spec, {_name, _, _args}, _}) do
    # Can safely ignore this spec since it does not define return type.
    # It will be caught by compiler during next stage of compilation.
    :incomplete_spec
  end

  defp body_ret_pair([{name, _line, args}, output_tuple]) do
    name
    |> body(args)
    |> add_return_type(output_tuple)
  end

  defp body(name, args) do
    argkv = parse_args(args)
    %{name: name, arity: length(argkv), args: argkv}
  end

  defp add_return_type(res, term) do
    return_type = parse_term(term)
    Map.put(res, :returns, return_type)
  end

  defp parse_term(atom) when is_atom(atom), do: atom
  defp parse_term(list) when is_list(list), do: for(t <- list, do: parse_term(t))
  defp parse_term({el1, el2}), do: {parse_term(el1), parse_term(el2)}

  defp parse_term({:{}, _, tuple_els}) do
    list = for t <- tuple_els, do: parse_term(t)
    :erlang.list_to_tuple(list)
  end

  defp parse_term({:%{}, _, list}), do: {:map, parse_term(list)}
  defp parse_term({:|, _, alts}), do: parse_alternative(alts)
  defp parse_term({{:., _, iex_alias}, _, _}), do: parse_alias(iex_alias)
  defp parse_term({atom, _, nil}) when is_atom(atom), do: atom

  defp parse_alternative(list) do
    alts = for term <- list, do: parse_term(term)
    {:alternative, alts}
  end

  defp parse_alias([{:__aliases__, _, prefixes} | [last]]) do
    prefixes = for prefix <- prefixes, do: Atom.to_string(prefix)
    String.to_atom(Enum.join(prefixes ++ [last], "."))
  end

  defp parse_alias([left | [right]]) do
    String.to_atom(Enum.join([left | [right]], "."))
  end

  defp parse_args(args) do
    # keyword list (not a map) because we care about order!
    for arg <- args, do: function_arg(arg)
  end

  defp function_arg({:::, _, [argname, argtype]}) do
    {parse_term(argname), parse_term(argtype)}
  end

  # in correct spec this is always a argtype, never an argname
  defp function_arg({argtype, _, nil}), do: argtype

  # Sanity check since functions of the same name
  # but different arity are not yet handled.
  defp arity_sanity_check(list) do
    names = for {name, _} <- list, do: name
    testresult = length(Enum.uniq(names)) != length(names)
    if testresult, do: :problem_with_arity, else: :ok
  end

  defmacro __using__(_opts) do
    quote do
      import OmiseGO.API.ExposeSpec

      @before_compile OmiseGO.API.ExposeSpec
    end
  end

  defmacro __before_compile__(env) do
    module = env.module

    nice_spec =
      module
      |> Module.get_attribute(:spec)
      |> Enum.map(&function_spec/1)
      |> Enum.filter(fn x -> x != :incomplete_spec end)
      |> Enum.map(fn map -> {map[:name], map} end)

    :ok = arity_sanity_check(nice_spec)
    escaped = Macro.escape(Map.new(nice_spec))

    quote do
      def get_specs, do: unquote(escaped)
    end
  end
end
