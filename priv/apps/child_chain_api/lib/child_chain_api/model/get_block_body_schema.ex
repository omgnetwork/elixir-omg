# NOTE: This class is auto generated by OpenAPI Generator (https://openapi-generator.tech).
# https://openapi-generator.tech
# Do not edit the class manually.

defmodule ChildChainAPI.Model.GetBlockBodySchema do
  @moduledoc """

  """

  @derive [Poison.Encoder]
  defstruct [
    :hash
  ]

  @type t :: %__MODULE__{
          :hash => String.t()
        }
end

defimpl Poison.Decoder, for: ChildChainAPI.Model.GetBlockBodySchema do
  def decode(value, _options) do
    value
  end
end
