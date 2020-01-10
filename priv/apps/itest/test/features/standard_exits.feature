Feature: Standard Exits
  Scenario: Alice starts a Standard Exit
    When Alice deposits "1" ETH to the network
    Then Alice should have "1" ETH on the network
    When Alice starts a standard exit on the network
    Then Alice should have "0" ETH on the network after finality margin
    And Alice should have "100" ETH on the blockchain
