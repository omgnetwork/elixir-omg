Feature: In Flight Exits
  Scenario: Alice starts an In Flight Exit
    When Alice deposits "1" ETH to the root chain
    Then Alice should have "1" ETH on the root chain after finality margin
    When Alice starts an in flight exit
    Then Alice should have "1" ETH after finality margin