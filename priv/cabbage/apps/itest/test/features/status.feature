Feature: Status
  Scenario: Alice checks the Watcher's status
    When Alice checks the Watcher's status
    Then Alice can read last_seen_eth_block_number as integer
    Then Alice can read last_seen_eth_block_timestamp as a datetime
    Then Alice can read eth_syncing as a boolean
    Then Alice can read contract_addr as a map
    Then Alice can read the plasma framework's contract address
    Then Alice can read the ETH vault's contract address
    Then Alice can read the ERC-20 vault's contract address
    Then Alice can read the payment exit game's contract address
    Then Alice can read the name and synced height of each internal service
