Feature: Watcher info

  Scenario: Alice wants to use retrieve her UTXO information after deposit
    When Alice deposit "1" ETH to the root chain creating 1 utxo
    Then Alice should able to call watcher_info /account.get_utxos and it return the utxo and the paginating content correctly
