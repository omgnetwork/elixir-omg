defmodule OMG.Watcher.Web.View.Status do
  use OMG.Watcher.Web, :view

  alias OMG.Watcher.Web.Serializer

  def render("status.json", %{status: status}) do
    status
    |> Serializer.Response.serialize(:success)
  end

end