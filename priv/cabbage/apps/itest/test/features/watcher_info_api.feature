Feature: Watcher info

  Scenario: Alice wants to use retrieve her UTXO information after deposit
    When Alice deposits "1" ETH to the root chain creating 1 UTXO
    Then Alice is able to paginate her single UTXO
    When Alice deposits another "2" ETH to the root chain creating second UTXO
    Then Alice is able to paginate 2 UTXOs correctly
    When Alice send "1" ETH to bob on the child chain
    Then Api able to list transaction correctly wuth end_datetime
