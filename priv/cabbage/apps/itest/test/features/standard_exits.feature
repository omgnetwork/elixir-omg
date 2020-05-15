Feature: Standard Exits
  Scenario: Alice starts a Standard Exit for ETH
    When Alice deposits "1" ETH to the root chain
    Then Alice should have "1" ETH on the child chain
    When Alice starts a standard exit on the child chain
    Then Alice should no longer see the exiting utxo on the child chain
    When Alice processes the standard exit on the child chain
    Then Alice should have "0" ETH on the child chain after finality margin
    And Alice should have "100" ETH on the root chain

  Scenario: Alice starts a Standard Exit for ERC-20
    When Alice deposits "1" ERC20 to the root chain
