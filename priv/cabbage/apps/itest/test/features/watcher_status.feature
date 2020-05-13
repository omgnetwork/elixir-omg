Feature: Watcher Status
  Scenario: Operator deploys Watcher
    When Operator requests the watcher's status
    Then Operator can read "plasma_framework" contract address
    And Operator can read "eth_vault" contract address
    And Operator can read "erc20_vault" contract address
    And Operator can read "payment_exit_game" contract address
