Feature: Transaction fees are claimed

  Scenario: Operator claims the fees from transactions
    When "Alice" deposits "3" ETH to the root chain
    Then "Alice" should have "3" ETH on the child chain
    When "Alice" sends "Bob" "2" ETH on the child chain
    Then "Bob" should have "2" ETH on the child chain
    And Operator has claimed the fees
