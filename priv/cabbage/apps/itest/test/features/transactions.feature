Feature: Transactions

  Scenario: 50 entities exchange ETH
    When they deposit "1" ETH to the root chain
    And they deposit "1" ETH to the root chain
    Then they should have "2" ETH on the child chain
    When they send others "1" ETH on the child chain
    Then others should have "1" ETH on the child chain
