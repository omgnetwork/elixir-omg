Feature: Watcher Status
  Scenario: Operator deploys Watcher
    When Operator requests the watcher's status
    Then Operator can read "plasma_framework" contract address
    And Operator can read "eth_vault" contract address
    And Operator can read "erc20_vault" contract address
    And Operator can read "payment_exit_game" contract address
    And Operator can read byzantine_events
    And Operator can read eth_syncing
    And Operator can read in_flight_exits
    And Operator can read last_mined_child_block_number
    And Operator can read last_mined_child_block_timestamp
    And Operator can read last_seen_eth_block_number
    And Operator can read last_seen_eth_block_timestamp
    And Operator can read last_validated_child_block_number
    And Operator can read last_validated_child_block_timestamp
    And Operator can read services_synced_heights

