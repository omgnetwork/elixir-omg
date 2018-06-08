# Used by "mix format"
# see apps/omisego_eth/config/.formatter.exs for explanation of the inputs/subdirectories
# TODO: fix that thing someday
[
  inputs: [
    "mix.exs",
    "apps/*/mix.exs",
    "apps/*/{lib,test}/**/*.{ex,exs}",
    "apps/omisego_api/config/**/*.{ex,exs}",
    "apps/omisego_db/config/**/*.{ex,exs}",
    "apps/omisego_jsonrpc/config/**/*.{ex,exs}",
    "apps/omisego_performance/config/**/*.{ex,exs}",
    "apps/omisego_watcher/config/**/*.{ex,exs}"
  ],
  subdirectories: ["apps/omisego_eth/config"],
  line_length: 120
]
