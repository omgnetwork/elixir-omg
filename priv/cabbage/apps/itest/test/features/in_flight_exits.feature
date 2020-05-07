Feature: In Flight Exits
  Scenario: Alice starts an In Flight Exit
    Given "Alice" deposits "10" ETH to the root chain
    Given "Bob" deposits "10" ETH to the root chain
    Then "Alice" should have "10" ETH on the child chain after finality margin
    Then "Bob" should have "10" ETH on the child chain after finality margin
    Given Alice and Bob create a transaction for "5" ETH
    And Bob gets in flight exit data for "5" ETH from his most recent deposit
    And Alice sends the most recently created transaction
    And Bob spends an output from the most recently sent transaction
    And Alice starts an in flight exit from the most recently created transaction
    Then "Alice" verifies its in flight exit from the most recently created transaction
    Given Bob piggybacks inputs and outputs from Alices most recent in flight exit
    And Bob starts a piggybacked in flight exit using his most recently prepared in flight exit data
    And Alice fully challenges Bobs most recent invalid in flight exit
    Then "Alice" can processes its own most recent in flight exit
      
  Scenario: Standard exit invalidated with an In Flight Exit
    Given "Alice" deposits "10" ETH to the root chain
    Then "Alice" should have "10" ETH on the child chain after finality margin
    Given "Bob" deposits "10" ETH to the root chain
    Then "Bob" should have "10" ETH on the child chain after finality margin
    Given Bob sends Alice "5" ETH on the child chain
    Then "Alice" should have "15" ETH on the child chain after a successful transaction
    Given Alice creates a transaction spending her recently received input to Bob
    And Bob starts an in flight exit from the most recently created transaction
    Then "Bob" verifies its in flight exit from the most recently created transaction
    Given Bob piggybacks outputs from his most recent in flight exit
    And Alice starts a standard exit on the child chain from her recently received input from Bob
    And Alice piggybacks inputs from Bobs most recent in flight exit
    And Bob fully challenges Alices most recent invalid exit
    Then "Bob" can processes its own most recent in flight exit