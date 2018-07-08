defmodule OmiseGO.API.GenServerHelper do
  @moduledoc """
  Generates dumb GenServer callback module for chosen pure library.
  For use with proper_statem.
  """
  defmacro __using__(_opts) do
    quote do
      @before_compile OmiseGO.API.GenServerHelper
    end
  end

  defmacro __before_compile__(opts) do
    specials = [__info__: 1, __struct__: 0, __struct__: 1, module_info: 0, module_info: 1]
    core =  hd(opts.context_modules)
    exports = Module.definitions_in(core, :def)
    exports = exports -- specials

    module_static = quote do
      def init(state) do
        Process.put(unquote(core), state)
        {:ok, :state_managed_by_helper}
      end

      def reset() do
        Process.put(unquote(core), nil)
      end
    end

    contents = [module_static]

    exports = for {func_name, arity} <- exports do
      args = for x <- :lists.seq(1, arity-1) do
        argname = String.to_atom("arg#{inspect x}")
        {argname, [], nil}
      end
      {func_name, args}
    end

    module_api = Enum.map(exports, fn({func_name, args}) ->
      quote do
        def unquote(func_name)(unquote_splicing(args)) do
          state = Process.get(unquote(core))
          case :erlang.apply(unquote(core), unquote(func_name), unquote(args) ++ [state]) do
            {:ok, sideeffects, new_state} ->
              Process.put(unquote(core), new_state)
              {:ok, sideeffects}
            {:ok, new_state} ->
              Process.put(unquote(core), new_state)
              :ok
            {{:error, error}, new_state} ->
              Process.put(unquote(core), new_state)
              {:error, error}
          end
        end
      end
    end)
    contents = contents ++ module_api

    module_name =
      core
      |> Atom.to_string
      |> Kernel.<>("GS")
      |> String.to_atom

    Module.create(module_name, contents, Macro.Env.location(__ENV__))
    []
  end
end
