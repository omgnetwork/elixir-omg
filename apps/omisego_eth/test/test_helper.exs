ExUnit.configure(exclude: [requires_geth: true])
ExUnitFixtures.start()
ExUnitFixtures.load_fixture_files() # need to do this in umbrella apps
ExUnit.start()
