# Used by "mix format"
[
  inputs: [
    "rel/config.exs",
    "mix.exs",
    "apps/*/mix.exs",
    "apps/*/{lib,test,config}/**/*.{ex,exs}",
    "priv/*/config/config.exs",
    "priv/*/mix.exs",
  ]
  ++ (Path.wildcard("priv/*/apps/*/mix.exs") -- (Path.wildcard("priv/*/apps/watcher_info_api/mix.exs") ++ Path.wildcard("priv/*/apps/watcher_security_critical_api/mix.exs") ++ Path.wildcard("priv/*/apps/child_chain_api/mix.exs")))
  ++ (Path.wildcard("priv/*/apps/*/{lib,test,config}/**/*.{ex,exs}") -- (Path.wildcard("priv/*/apps/watcher_info_api/{lib,test,config}/**/*.{ex,exs}") ++ Path.wildcard("priv/*/apps/watcher_security_critical_api/{lib,test,config}/**/*.{ex,exs}") ++ Path.wildcard("priv/*/apps/child_chain_api/{lib,test,config}/**/*.{ex,exs}"))),
  line_length: 120
]
