defmodule OmiseGO.API.GenServerHelper do
  @moduledoc """
  Generates dumb GenServer callback module for chosen pure library.
  For use with proper_statem.
  """
  defmacro __using__(opts) do
    quote do
      @before_compile OmiseGO.API.GenServerHelper
    end
  end

  defmacro __before_compile__(opts) do
  # defmacro __using__(opts) do
    IO.puts("opts are #{inspect opts}")
    specials = [__info__: 1, __struct__: 0, __struct__: 1, module_info: 0, module_info: 1]
    # IO.puts("__CALLER__ is #{inspect __CALLER__}")
    # IO.puts("__MODULE__ is #{inspect __MODULE__}")
    # caller =  hd(__CALLER__.context_modules)
    caller =  hd(opts.context_modules)
    # exports = caller.module_info(:exports) -- specials
    exports = Module.definitions_in(caller, :def)
    IO.puts("definitions in #{inspect caller} are #{inspect exports}")
    exports = exports -- specials

    # IO.puts("module name is #{inspect __MODULE__}")
    # IO.puts("env is #{inspect __ENV__}")
    # IO.puts("caller is #{inspect __CALLER__}")

    module_use = quote do
      use GenServer
    end

    module_static = quote do
      def init(_) do
        {:ok, :nil}
      end
    end

    contents = [module_use] ++ [module_static]

    exports = for {func_name, arity} <- exports do
      args = for x <- :lists.seq(1, arity) do
        argname = String.to_atom("arg#{inspect x}")
        {argname, [], nil}
      end
      {func_name, arity, args}
    end

    IO.puts("exports are #{inspect exports}")

    module_api = Enum.map(exports, fn({func_name, arity, args}) ->
      quote do: def unquote(func_name)(unquote_splicing(args)), do: {:ok, unquote(arity)}
    end)
    contents = contents ++ module_api

    module_name =
      caller
      |> Atom.to_string
      |> Kernel.<>("GS")
      |> String.to_atom

    IO.puts("module name is #{inspect module_name}")
    Module.create(module_name, contents, Macro.Env.location(__ENV__))
    []
  end
end
