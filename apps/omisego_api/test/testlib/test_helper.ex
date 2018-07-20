defmodule OmiseGO.API.TestHelper do
  @moduledoc """
  Various shared functions used in API tests
  """

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.State.Transaction

  def entities do
    %{
      alice: generate_entity(),
      bob: generate_entity(),
      carol: generate_entity(),

      # Deterministic entities. Use only when truly needed.
      stable_alice: %{
        priv:
          <<54, 43, 207, 67, 140, 160, 190, 135, 18, 162, 70, 120, 36, 245, 106, 165, 5, 101, 183, 55, 11, 117, 126,
            135, 49, 50, 12, 228, 173, 219, 183, 175>>,
        addr: <<59, 159, 76, 29, 210, 110, 11, 229, 147, 55, 59, 29, 54, 206, 226, 0, 140, 190, 184, 55>>
      },
      stable_bob: %{
        priv:
          <<208, 253, 134, 150, 198, 155, 175, 125, 158, 156, 21, 108, 208, 7, 103, 242, 9, 139, 26, 140, 118, 50, 144,
            21, 226, 19, 156, 2, 210, 97, 84, 128>>,
        addr: <<207, 194, 79, 222, 88, 128, 171, 217, 153, 41, 195, 239, 138, 178, 227, 16, 72, 173, 118, 35>>
      },
      stable_mallory: %{
        priv:
          <<89, 253, 200, 245, 173, 195, 234, 62, 168, 206, 213, 19, 136, 51, 147, 209, 1, 14, 180, 107, 106, 8, 133,
            131, 75, 157, 81, 109, 102, 19, 91, 130>>,
        addr: <<48, 120, 88, 246, 235, 202, 79, 121, 216, 73, 40, 199, 165, 186, 120, 113, 36, 119, 87, 207>>
      }
    }
  end

  def generate_entity do
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, addr} = Crypto.generate_address(pub)
    %{priv: priv, addr: addr}
  end

  def do_deposit(state, owner, %{amount: amount, currency: cur, blknum: blknum}) do
    {:ok, {_, _}, new_state} =
      Core.deposit([%{owner: owner.addr, currency: cur, amount: amount, blknum: blknum}], state)

    new_state
  end

  @doc """
  convenience function around Transaction.new to create recovered transactions,
  by allowing to provider private keys of utxo owners along with the inputs
  """
  @spec create_recovered(
          list({pos_integer, pos_integer, 0 | 1, map}),
          Transaction.currency(),
          list({Crypto.address_t(), pos_integer})
        ) :: Transaction.Recovered.t()
  def create_recovered(inputs, currency, outputs) do
    signed_tx = create_signed(inputs, currency, outputs)
    {:ok, recovered} = Transaction.Recovered.recover_from(signed_tx)
    recovered
  end

  @doc """
  convenience function around Transaction.new to create signed transactions (see create_recovered)
  """
  @spec create_signed(
          list({pos_integer, pos_integer, 0 | 1, map}),
          Transaction.currency(),
          list({Crypto.address_t(), pos_integer})
        ) :: {Transaction.Signed.t(), Transaction.t()}
  def create_signed(inputs, currency, outputs) do
    raw_tx =
      Transaction.new(
        inputs |> Enum.map(fn {blknum, txindex, oindex, _} -> {blknum, txindex, oindex} end),
        currency,
        outputs |> Enum.map(fn {newowner, amount} -> {newowner.addr, amount} end)
      )

    [priv1, priv2 | _] = inputs |> Enum.map(fn {_, _, _, owner} -> owner.priv end) |> Enum.concat([<<>>, <<>>])

    Transaction.sign(raw_tx, priv1, priv2)
  end

  def create_encoded(inputs, cur12, outputs) do
    signed_tx = create_signed(inputs, cur12, outputs)
    Transaction.Signed.encode(signed_tx)
  end

  @spec encode_address(Crypto.address_t()) :: String.t()
  def encode_address(address) do
    "0x" <> Base.encode16(address, case: :lower)
  end
end
