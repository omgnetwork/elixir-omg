# ChildChainAPI

This is the documentation for child chain API. Error codes are available in [html](https://github.com/omisego/elixir-omg/blob/master/docs/api_specs/errors.md#error-codes-description) format. 

### Building

To install the required dependencies and to build the elixir project, run:
```
mix local.hex --force
mix do deps.get, compile
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `child_chain_api` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:child_chain_api, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/child_chain_api](https://hexdocs.pm/child_chain_api).
