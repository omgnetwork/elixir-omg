Feature: Deposits

  Scenario: Alice deposits funds into the contract
    When Alice deposits "1" ETH to the network
    And Alice deposits "1" ETH to the network
    Then Alice should have "2" ETH on the network

  Scenario: Alice sends Bob funds
    When Alice deposits "1" ETH to the network
    And Alice deposits "1" ETH to the network
    Then Alice should have "2" ETH on the network
    When Alice sends Bob "1" ETH on the network
    Then Bob should have "1" ETH on the network