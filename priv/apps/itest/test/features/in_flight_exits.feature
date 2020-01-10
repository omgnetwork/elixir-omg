Feature: In Flight Exits
  Scenario: Alice starts an In Flight Exit
    When "Alice" deposits "10" ETH to the network
    When "Bob" deposits "10" ETH to the network
    Then "Alice" should have "10" ETH on the network after finality margin
    Then "Bob" should have "10" ETH on the network after finality margin
    When Alice creates a transaction for "5" ETH
    Then Bob gets in flight exit data for "5" ETH
    Then Alice sends a transaction
    Then Bob sends a transaction spending Alices output
    When Alice starts an in flight exit
    Then Alice verifies its in flight exit
    Then Bob piggybacks inputs and outputs from Alice
    Then Bob starts a competing in flight exit
    Then Alice starts to challenge Bobs in flight exit
    
