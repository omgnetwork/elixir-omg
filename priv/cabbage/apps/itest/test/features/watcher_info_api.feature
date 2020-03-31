Feature: Watcher info

  Scenario: Alice want to use watcher info api
    When Alice deposit "1" ETH to the root chain creating 1 utxo
    Then Alice should able to call watcher_info /account.get_utxos and it return the utxo and the paginating content correctly
