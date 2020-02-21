Feature: Invalid Standard Exits
  Scenario: Alice starts an invalid Standard Exit
    When Alice deposits "12" ETH to the root chain
    Then Alice should have "12" ETH on the child chain
    When Alice sends Bob "1" ETH on the child chain
    Given Some state of the chain
    And Alice starts a standard exit on the child chain from her recently spent input
    Then Bob detects the new "invalid_exit" and challenges all
    And The child chain is secure
    When Alice tries to process exits
    And Alice should have no more than "11" ETH on the child chain
    And Alice should have "12" ETH less on the blockchain
