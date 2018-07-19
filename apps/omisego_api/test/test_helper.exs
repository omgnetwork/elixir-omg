ExUnit.configure(exclude: [integration: true, property: true])
Code.require_file("test/testlib/test_helper.ex")
Code.require_file("../omisego_eth/test/fixtures.exs")
Code.require_file("../omisego_db/test/fixtures.exs")
Application.ensure_all_started(:propcheck)
ExUnitFixtures.start()
# need to do this in umbrella apps
ExUnitFixtures.load_fixture_files()
ExUnit.start()
