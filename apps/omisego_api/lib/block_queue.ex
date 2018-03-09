defmodule OmiseGO.BlockQueue do
  @moduledoc """
  Responsible for keeping a queue of blocks lined up nicely for submission to Eth.
  In particular responsible for picking up, where it's left off (crashed) gracefully
  """

  ### Client

  def push_block(block)

  def status

  def submission_mined(height)

  ### Server

  # TODO

  defmodule Core do
    @moduledoc """
    Handles maintaining the queue of to-be-mined blocks
    """
    # TODO

    defstruct [:blocks, :last_submitted_height, :last_mined_submission, :last_formed_height]
  end

end
