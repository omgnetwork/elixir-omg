defmodule QuickStart do
  def start() do
    OmiseGO.PerfTest.setup_and_run(0,0)

    alice = OmiseGO.PerfTest.SenderServer.generate_participant_address()
    IO.puts "Alice addr #{Base.encode64(alice.addr)}"

    bob = OmiseGO.PerfTest.SenderServer.generate_participant_address()
    IO.puts "Bobby addr #{Base.encode64(bob.addr)}"

    :ok = OmiseGO.API.State.deposit([%{owner: alice.addr, amount: 10, blknum: 1}])

    alias OmiseGO.API.State.Transaction

    tx = %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        amount1: 1, amount2: 9, fee: 0,
        newowner1: bob.addr, newowner2: alice.addr }

    txe = tx |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()

    {result, blknum, txind, hash} = OmiseGO.API.submit(txe)
    IO.puts "Tx submit result: #{inspect result}\n blknum #{blknum}\n txind #{txind}"

    tx2 = %Transaction{
      blknum1: 1000, txindex1: 0, oindex1: 1, blknum2: 0, txindex2: 0, oindex2: 0, amount1: 3, amount2: 6, fee: 0,
      newowner1: bob.addr, newowner2: alice.addr }

    txe2 = tx2 |> Transaction.sign(alice.priv, <<>>) |> Transaction.Signed.encode()
    {result, blknum, txind, hash} = OmiseGO.API.submit(txe2)
    IO.puts "Tx submit result: #{inspect result}\n blknum #{blknum}\n txind #{txind}"
  end
end
