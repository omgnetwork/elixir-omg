Feature: Deposits

  Scenario: Alice deposits funds into the contract
    When Alice deposits "1" ETH to the root chain
    And Alice deposits "1" ETH to the root chain
    Then Alice should have "2" ETH on the child chain
    Then Alice should have the root chain balance changed by "-2" ETH

  Scenario: Alice sends Bob funds
    When Alice deposits "1" ETH to the root chain
    And Alice deposits "1" ETH to the root chain
    Then Alice should have "2" ETH on the child chain
    Then Alice should have the root chain balance changed by "-2" ETH
    When Alice sends Bob "1" ETH on the child chain
    Then Bob should have "1" ETH on the child chain