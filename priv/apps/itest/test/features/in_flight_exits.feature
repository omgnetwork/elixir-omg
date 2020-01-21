Feature: In Flight Exits
  Scenario: Alice starts an In Flight Exit
    When "Alice" deposits "10" ETH to the root chain
    When "Bob" deposits "10" ETH to the root chain
    Then "Alice" should have "10" ETH on the child chain after finality margin
    Then "Bob" should have "10" ETH on the child chain after finality margin
    When Alice creates a transaction for "5" ETH
    Then Bob gets in flight exit data for "5" ETH
    Then Alice sends a transaction tx1
    Then Bob sends a transaction spending Alices outputs of tx1
    When Alice starts an in flight exit of the tx1 transaction
    Then Alice verifies its in flight exit of tx1 transaction
    Then Bob piggybacks inputs and outputs from Alice
    Then Bob starts a competing in flight exit
    Then Alice fully challenges Bobs in flight exit
    Then Alice processes its own exit
    
