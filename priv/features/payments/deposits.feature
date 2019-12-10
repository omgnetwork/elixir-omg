Feature: Depositing
  Scenario: Alice deposits funds
    When Alice deposits "1" ETH
    And Alice deposits "1" ETH
    Then Alice should have "2" ETH

  Scenario: Alice sends Bob funds
    When Alice deposits "1" ETH
    And Alice deposits "1" ETH
    Then Alice should have "2" ETH
    When Alice sends Bob "1" ETH
    Then Bob should have "1" ETH
