Feature: In Flight Exits
  # NB: Since the in flight transaction doesn't exist in the system
  # you don't actually exit any money.
  Scenario: Alice starts an In Flight Exit
    When Alice deposits "1" ETH
    Then Alice should have "1" ETH
    When Alice starts an in flight exit
    Then Alice should have "1" ETH after finality margin
