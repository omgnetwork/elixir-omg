# Used by "mix format"
[
  inputs: [
    "rel/config.exs",
    "mix.exs",
    "apps/*/mix.exs",
    "apps/*/{lib,test,config}/**/*.{ex,exs}",
    "priv/config/config.exs",
    "priv/mix.exs",
    "priv/features/contexts/*.exs",
  ]
  ++ Path.wildcard("apps/*/mix.exs") -- (Path.wildcard("apps/watchers_informational_api/mix.exs") ++ Path.wildcard("apps/watcher_security_critical_api/mix.exs") ++ Path.wildcard("apps/child_chain_api/mix.exs"))
  ++ Path.wildcard("apps/*/{lib,test,config}/**/*.{ex,exs}") -- (Path.wildcard("apps/watchers_informational_api/{lib,test,config}/**/*.{ex,exs}") ++ Path.wildcard("apps/watcher_security_critical_api/{lib,test,config}/**/*.{ex,exs}") ++ Path.wildcard("apps/child_chain_api/{lib,test,config}/**/*.{ex,exs}")),
  line_length: 120
]
