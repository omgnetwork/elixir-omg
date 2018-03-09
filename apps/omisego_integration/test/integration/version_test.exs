defmodule HonteD.Integration.VersionTest do
  @moduledoc """
  Intends to make a quick check whether the binaries available are at their correct versions
  """
  use ExUnit.Case, async: false

  @moduletag :integration

  test "Tendermint at supported version" do
    %Porcelain.Result{err: nil, status: 0, out: version_output} = Porcelain.shell(
      "tendermint version"
    )
    version_output
    |> String.trim
    |> Version.match?("~> 0.15")
    |> assert
  end
end
