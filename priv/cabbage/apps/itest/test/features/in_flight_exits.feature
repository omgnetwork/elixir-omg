Feature: In Flight Exits
  Scenario: Alice starts an In Flight Exit
    Given "Alice" deposits "10" ETH to the root chain
    Given "Bob" deposits "10" ETH to the root chain
    Then "Alice" should have "10" ETH on the child chain after finality margin
    Then "Bob" should have "10" ETH on the child chain after finality margin
    Given Alice and Bob create a transaction for "5" ETH
    And Bob gets in flight exit data for "5" ETH from his most recent deposit
    And Alice sends the most recently created transaction
    And Bob sends the most recently created transaction
    And Alice starts an in flight exit from the most recently created transaction
    Then Alice verifies its in flight exit from the most recently created transaction
    Given Bob piggybacks inputs and outputs from Alices most recent in flight exit
    And Bob starts an in flight exit from his most recently created transaction
    And Alice fully challenges Bobs most recent invalid in flight exit
    Then Alice can processes her own most recent in flight exit