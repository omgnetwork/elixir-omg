Logger.configure_backend(:console, colors: [enabled: false])
alias Itest.Transactions.Encoding
Application.ensure_all_started(:ethereumex)
data = ABI.encode("minExitPeriod()", [])
{:ok, result} = Ethereumex.HttpClient.eth_call(%{to: Itest.Account.plasma_framework(), data: Encoding.to_hex(data)})

miliseconds =
  result
  |> Encoding.to_binary()
  |> ABI.TypeDecoder.decode([{:uint, 160}])
  |> hd()
  # to milliseconds
  |> Kernel.*(1_000)
  # add a minute for the rest of the test
  |> Kernel.+(60_000)

ExUnit.start(trace: "--trace" in System.argv(), timeout: miliseconds)
