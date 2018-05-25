Code.load_file("test/testlib/test_helper.ex")
Code.require_file("../omisego_eth/test/fixtures.exs")
ExUnitFixtures.start()
# need to do this in umbrella apps
ExUnitFixtures.load_fixture_files()
ExUnit.start()
