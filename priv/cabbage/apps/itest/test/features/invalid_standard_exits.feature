Feature: Invalid Standard Exits
  Scenario: Alice starts an invalid Standard Exit
    Given Alice has "12" ETH on the child chain
    And The child chain is secure
    When Alice sends Bob "1" ETH on the child chain
    And Alice starts a standard exit on the child chain from her recently spent input
    But Bob detects an "invalid_exit" and challenges it
    And Alice tries to process exits
    Then The child chain is secure
    And Alice should have "12" ETH less on the blockchain
