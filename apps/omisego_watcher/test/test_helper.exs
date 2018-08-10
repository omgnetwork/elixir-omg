ExUnit.configure(exclude: [integration: true])
Code.require_file("../omisego_eth/test/fixtures.exs")
Code.require_file("../omisego_db/test/fixtures.exs")
Code.require_file("../omisego_api/test/fixtures.exs")
ExUnitFixtures.start()
# need to do this in umbrella apps
ExUnitFixtures.load_fixture_files()
ExUnit.start()
