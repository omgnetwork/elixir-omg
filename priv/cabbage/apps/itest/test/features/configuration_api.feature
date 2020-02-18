Feature: Configuration API
  Scenario: Operator deploys Child Chain, Watcher and Watcher Info
    When Operator deploys "Child Chain"
    Then Operator can read its configurational values
    When Operator deploys "Watcher"
    Then Operator can read its configurational values
    When Operator deploys "Watcher Info"
    Then Operator can read its configurational values
