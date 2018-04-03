defmodule Eth do
  @moduledoc false

  def submit_block(_nonce, _hash, _gas), do: :ok

  def get_ethereum_height, do: {:ok, 12_345_678}

  def get_root_deployment_height, do: {:ok, 12_345_678}

  def get_current_child_block, do: {:ok, 1_005_000}

  def get_child_block_root(_num), do: {:ok, "hash"}

end
