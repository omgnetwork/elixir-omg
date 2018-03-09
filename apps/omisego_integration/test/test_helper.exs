# because we want to use mix test --no-start by default
[:porcelain, :hackney]
|> Enum.map(&Application.ensure_all_started/1)

ExUnit.configure(exclude: [integration: true])
ExUnitFixtures.start()
ExUnitFixtures.load_fixture_files() # need to do this in umbrella apps
ExUnit.start()
