Feature: Standard Exits
  Scenario: Alice starts a Standard Exit
    When Alice deposits "1" ETH
    Then Alice should have "1" ETH
    When Alice starts a standard exit
    Then Alice should have "0" ETH after finality margin
