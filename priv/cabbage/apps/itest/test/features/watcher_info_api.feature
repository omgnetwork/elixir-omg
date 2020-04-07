Feature: Watcher info

  Scenario: Alice want to use watcher info api
    When Alice deposits "1" ETH to the root chain creating 1 UTXO
    Then Alice is able to paginate her single UTXO
    When Alice deposits another "2" ETH to the root chain creating second UTXO
    Then Alice is able to paginate 2 UTXOs correctly
