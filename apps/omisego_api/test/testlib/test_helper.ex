defmodule OmiseGO.API.TestHelper do
  @moduledoc """
  Various shared functions used in API tests
  """

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.Eth

  def generate_entity do
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, addr} = Crypto.generate_address(pub)
    %{priv: priv, addr: addr}
  end

  def do_deposit(state, owner, %{amount: amount, blknum: blknum}) do
    {_, _, new_state} =
      Core.deposit([%{owner: owner.addr, amount: amount, blknum: blknum}], state)

    new_state
  end

  @spec create_recovered(
          list({pos_integer, pos_integer, 0 | 1}),
          list({<<_::256>>, pos_integer}),
          pos_integer
        ) :: Transaction.Recovered.t()
  def create_recovered(inputs, outputs, fee \\ 0) do
    raw_tx =
      Transaction.new(
        inputs |> Enum.map(fn {blknum, txindex, oindex, _} -> {blknum, txindex, oindex} end),
        outputs |> Enum.map(fn {newowner, amout} -> {newowner.addr, amout} end),
        fee
      )

    [sig1, sig2 | _] =
      inputs |> Enum.map(fn {_, _, _, owner} -> owner.priv end) |> Enum.concat([<<>>, <<>>])

    Transaction.Recovered.recover_from(Transaction.sign(raw_tx, sig1, sig2))
  end

  def import_unlock_fund(account) do

    account_priv_enc = Base.encode16(account.priv)
    account_enc = "0x" <> Base.encode16(account.addr, case: :lower)

    {:ok, ^account_enc} = Ethereumex.HttpClient.personal_import_raw_key(account_priv_enc, "")
    {:ok, true} = Ethereumex.HttpClient.personal_unlock_account(account_enc, "", 0)

    {:ok, [eth_source_address | _]} = Ethereumex.HttpClient.eth_accounts()
    txmap = %{from: eth_source_address, to: account_enc, value: "0x99999999999999999999999"}
    {:ok, tx_fund} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, _} = Eth.WaitFor.eth_receipt(tx_fund)

    {:ok, account_enc}
  end

end
