[
  inputs: [
    "rel/config.exs",
    "mix.exs",
    "features/*/*.{ex,exs}",
    "features/config.exs",
    "apps/*/mix.exs",
    "apps/*/{lib,test,config}/**/*.{ex,exs}",
    "priv/config/config.exs"
  ]
  ++ (Path.wildcard("apps/*/mix.exs") -- ["apps/watcher_info_api/mix.exs", "apps/watcher_security_critical_api/mix.exs", "apps/child_chain_api/mix.exs"])
  ++ (Path.wildcard("apps/*/{lib,test,config}/**/*.{ex,exs}") -- (Path.wildcard("apps/watcher_info_api/{lib,test,config}/**/*.{ex,exs}") ++ Path.wildcard("apps/watcher_security_critical_api/{lib,test,config}/**/*.{ex,exs}") ++ Path.wildcard("apps/child_chain_api/{lib,test,config}/**/*.{ex,exs}"))),
  line_length: 120,
  subdirectories: ["apps/*"]
]
