defmodule OMG.Watcher.Web.View.Challenge do
  use OMG.Watcher.Web, :view

  alias OMG.Watcher.Web.Serializer

  def render("challenge.json", %{challenge: challenge}) do
    challenge
    |> Serializer.Response.serialize(:success)
  end

end