# Used by "mix format"
[
  inputs: [
    "rel/config.exs",
    "mix.exs",
    "apps/*/mix.exs",
    "apps/*/{lib,test,config}/**/*.{ex,exs}",
    "features/*/*.{ex,exs}",
    "features/config.exs"
  ],
  line_length: 120,
  subdirectories: ["apps/*"]
]
