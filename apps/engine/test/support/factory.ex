defmodule Engine.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Engine.Repo

  def deposit_factory do
    %Engine.Transaction{
      tx_type: 1,
      tx_data: 0,
      metadata: <<0::160>>,
      outputs: build(:output_utxo)
    }
  end

  def transaction_factory do
    %Engine.Transaction{
      tx_type: 1,
      tx_data: 0,
      metadata: <<0::160>>,
      inputs: [build(:input_utxo)],
      outputs: [build(:output_utxo)]
    }
  end

  def input_utxo_factory do
    %Engine.Utxo{
      blknum: :rand.uniform(100),
      txindex: 0,
      oindex: 0,
      owner: <<1::160>>,
      currency: <<0::160>>,
      amount: :rand.uniform(100)
    }
  end

  def spent_utxo_factory do
    %Engine.Utxo{
      blknum: :rand.uniform(100),
      txindex: 0,
      oindex: 0,
      owner: <<1::160>>,
      currency: <<0::160>>,
      amount: :random.uniform(100),
      spending_transaction: build(:transaction)
    }
  end

  def output_utxo_factory do
    %Engine.Utxo{
      owner: <<1::160>>,
      currency: <<0::160>>,
      amount: :rand.uniform(100)
    }
  end
end
