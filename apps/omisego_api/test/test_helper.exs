ExUnit.configure(exclude: [integration: true, property: true])
Application.ensure_all_started(:propcheck)
ExUnitFixtures.start()
# loading all fixture files from the whole umbrella project
ExUnitFixtures.load_fixture_files("../**/test/**/fixtures.exs")
ExUnit.start()
