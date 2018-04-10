ExUnit.configure(exclude: [requires_geth: true])
ExUnitFixtures.start()
# need to do this in umbrella apps
ExUnitFixtures.load_fixture_files()
ExUnit.start()

