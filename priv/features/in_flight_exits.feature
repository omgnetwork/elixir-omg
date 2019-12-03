Feature: In Flight Exits
  Scenario: Alice starts an In Flight Exit
    When Alice deposits "1" ETH to the network
    Then Alice should have "1" ETH on the network
    When Alice starts an in flight exit on the network
    #When Alice starts an in flight exit on the network with transaction above
    #Then Alice should have "0" ETH on the network after finality margin
    #And Alice should have "100000" ETH on the blockchain
