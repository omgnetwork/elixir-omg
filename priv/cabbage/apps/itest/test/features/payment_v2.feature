Feature: Payment V2 transaction

  Scenario: 2 entities exchange ETH with payment v1 and v2
    When they deposit "4" ETH to the root chain
    Then they should have "4" ETH on the child chain
    When they send others "1" ETH on the child chain with payment v1
    Then others should have "1" ETH on the child chain
    When they send others "2" ETH on the child chain with payment v2
    Then others should have "3" ETH on the child chain
