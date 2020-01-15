Feature: Service Name
  Scenario: Operator deploys Child Chain, Watcher and Watcher Info
    When Operator deploys "Child Chain"
    Then Operator can read it's service name as "child_chain"
    When Operator deploys "Watcher"
    Then Operator can read it's service name as "watcher"
    When Operator deploys "Watcher Info"
    Then Operator can read it's service name as "watcher_info"
