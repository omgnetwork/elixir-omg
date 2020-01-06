Feature: Standard Exits
  Scenario: Alice starts a Standard Exit
    When Alice deposits "1" ETH to the network
    Then Alice should have "1" ETH on the network
    When Alice starts a standard exit on the network
    Then Alice should have "0" ETH on the network after finality margin
    And Alice should have "100" ETH on the blockchain

  Scenario: Alice and Bob starts a Standard Exit each
    When Alice deposits "1" ETH to the network
    Then Alice should have "1" ETH on the network
    When Bob deposits "1" ETH to the network
    Then Bob should have "1" ETH on the network
    When Alice starts a standard exit on the network
    And Bob starts a standard exit on the network
    Then Alice should have "0" ETH on the network after finality margin
    And Bob should have "0" ETH on the network after finality margin
    And Alice should have "100" ETH on the blockchain
    And Bob should have "100" ETH on the blockchain
