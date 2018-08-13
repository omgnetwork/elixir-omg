ExUnit.configure(exclude: [wrappers: true])
ExUnitFixtures.start()
# loading all fixture files from the whole umbrella project
ExUnitFixtures.load_fixture_files("../**/test/**/fixtures.exs")
ExUnit.start()
