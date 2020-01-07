defmodule WhiteBreadConfig do
  use WhiteBread.SuiteConfiguration

  suite(
    name: "All",
    context: WhiteBreadContext,
    feature_paths: ["features/"],
    run_async: false
  )
end
