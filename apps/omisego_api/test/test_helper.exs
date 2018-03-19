Code.load_file("test/testlib/test_helper.ex")
ExUnitFixtures.start()
ExUnitFixtures.load_fixture_files() # need to do this in umbrella apps
ExUnit.start()
