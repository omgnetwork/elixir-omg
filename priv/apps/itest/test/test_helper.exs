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
  # add two minutes for the rest of the test
  |> Kernel.+(120_000)

### parse contract addresses:
local_umbrella_path = Path.join([File.cwd!(), "../../../", "localchain_contract_addresses.env"])

contract_addreses_path =
  case File.exists?(local_umbrella_path) do
    true ->
      local_umbrella_path

    _ ->
      # CI/CD
      Path.join([File.cwd!(), "localchain_contract_addresses.env"])
  end

contracts =
  contract_addreses_path
  |> File.read!()
  |> String.split("\n", trim: true)
  |> List.flatten()
  |> Enum.reduce(%{}, fn line, acc ->
    [key, value] = String.split(line, "=")
    Map.put(acc, key, value)
  end)

Application.put_env(:ex_plasma, :eip_712_domain,
  name: "OMG Network",
  salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
  verifying_contract: contracts["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"],
  version: "1"
)

ExUnit.start(trace: "--trace" in System.argv(), timeout: miliseconds)
