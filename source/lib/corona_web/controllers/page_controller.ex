defmodule CoronaWeb.PageController do
  use CoronaWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def start(conn, _params) do
    render(conn, "start.html")
  end

  def show(conn, _params) do
    render(conn, "display.html")
  end
end
