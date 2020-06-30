Feature: Payment V2 transaction

  Scenario: Alice sends Bob ETH with payment v1 and v2
    When Alice deposits "4" ETH to the root chain
    Then Alice should have "4" ETH on the child chain
    When Alice sends Bob "1" ETH on the child chain with payment v1
    Then Bob should have "1" ETH on the child chain
    When Alice sends Bob "2" ETH on the child chain with payment v2
    Then Bob should have "3" ETH on the child chain

  Scenario: payment V2 output can exit and is recognized
    When Alice deposits "4" ETH to the root chain
    Then Alice should have "4" ETH on the child chain
    When Alice sends Bob "2" ETH on the child chain with payment v2
    Then Bob should have "2" ETH on the child chain
    When Bob starts a standard exit with the payment v2 output
    Then Bob should no longer see the exiting utxo on the child chain
    When Alice processes the standard exit on the child chain
    Then Bob should have "0" ETH on the child chain
