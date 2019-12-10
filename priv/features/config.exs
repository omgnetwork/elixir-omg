defmodule WhiteBreadConfig do
  use WhiteBread.SuiteConfiguration

  suite(
    name: "Payments",
    context: PaymentContext,
    feature_paths: ["features/payments/"],
    run_async: true
  )
end
