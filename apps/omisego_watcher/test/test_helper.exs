ExUnit.configure(exclude: [integration: true])
# TODO check why we don't need this
# ExUnitFixtures.start()
Code.require_file("test/testlib/test_helper.ex")
Code.require_file("../omisego_api/test/testlib/test_helper.ex")
Code.require_file("../omisego_eth/test/fixtures.exs")
Code.require_file("../omisego_db/test/fixtures.exs")
Code.require_file("../omisego_api/test/fixtures.exs")
# need to do this in umbrella apps
ExUnitFixtures.load_fixture_files()
ExUnit.start()
