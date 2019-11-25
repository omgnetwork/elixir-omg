# NOTE: This class is auto generated by OpenAPI Generator (https://openapi-generator.tech).
# https://openapi-generator.tech
# Do not edit the class manually.

defmodule WatchersInformationalAPI.Model.GetAllTransactionsBodySchema1 do
  @moduledoc """

  """

  @derive [Poison.Encoder]
  defstruct [
    :address,
    :blknum,
    :metadata,
    :page,
    :limit
  ]

  @type t :: %__MODULE__{
          :address => String.t() | nil,
          :blknum => integer() | nil,
          :metadata => String.t() | nil,
          :page => integer() | nil,
          :limit => integer() | nil
        }
end

defimpl Poison.Decoder, for: WatchersInformationalAPI.Model.GetAllTransactionsBodySchema1 do
  def decode(value, _options) do
    value
  end
end
