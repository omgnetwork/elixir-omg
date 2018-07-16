defmodule OmiseGO.API.BlackBoxMe do
  @moduledoc """
  Generates dumb wrapper for pure library that keeps state in process dictionary.
  Wrapper creates module with :"GS" attached at the end.

  Example:
  ```
  defmodule YourProject.State.Core do
    use OmiseGO.API.BlackBoxMe
    ...

  ```
  would create a YourProject.State.CoreGS module, accessible in every MIX_ENV.

  Pure library is presumed to have following interface:
  -spec funX(arg1, ..., argN, state) :: {:ok, side_effects(), state} | {{:error, term}, state}
  Wrapper exports the same functions with arity-1 (state is hidden) and returns tuples that are shorted by one item (state is hidden). Example above would have been transformed into:
  -spec funX(arg1, ..., argN) :: {:ok, side_effects()} | {:error, term}

  This allows for black-box testing and more importantly - for interaction with proper_statem and proper_fsm.

  Wrapper adds following helper functions:

  # initiate state with call to this:
  @spec init(state()) :: {:ok, :state_managed_by_helper}

  # cleanup state stored in process dictionary
  @spec reset() :: state() | nil

  # get state stored in process dictionary (for possible inspection)
  @spec get_state() :: state() | nil

  """
  defmacro __using__(_opts) do
    quote do
      @before_compile OmiseGO.API.BlackBoxMe
    end
  end

  defmacro __before_compile__(opts) do
    specials = [__info__: 1, __struct__: 0, __struct__: 1, module_info: 0, module_info: 1]
    core = hd(opts.context_modules)
    exports = Module.definitions_in(core, :def)
    exports = exports -- specials

    module_static =
      quote do
        def init(state) do
          Process.put(unquote(core), state)
          {:ok, :state_managed_by_helper}
        end

        def reset do
          Process.put(unquote(core), nil)
        end

        def get_state do
          Process.get(unquote(core))
        end
      end

    contents = [module_static]

    exports =
      for {func_name, arity} <- exports do
        args =
          for x <- :lists.seq(1, arity - 1) do
            argname = String.to_atom("arg#{inspect(x)}")
            {argname, [], nil}
          end

        {func_name, args}
      end

    module_api =
      Enum.map(exports, fn {func_name, args} ->
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

              unexpected ->
                IO.puts(
                  "unexpected output #{inspect(unquote(func_name)(unquote_splicing(args)))} :: #{inspect(unexpected)}"
                )

                :erlang.error({:badreturn, unexpected})
            end
          end
        end
      end)

    contents = contents ++ module_api

    module_name =
      core
      |> Atom.to_string()
      |> Kernel.<>("GS")
      |> String.to_atom()

    # generate the helper module:
    {:module, _, _, _} = Module.create(module_name, contents, Macro.Env.location(__ENV__))
    # but don't introduce any changes into caller module:
    []
  end
end
