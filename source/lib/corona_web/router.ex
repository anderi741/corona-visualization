defmodule CoronaWeb.Router do
  use CoronaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CoronaWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/start", PageController, :start
    get "/sim", PageController, :show
  end

  # Other scopes may use custom stacks.
  scope "/api", CoronaWeb do
    pipe_through :api

    get "/infected", InfectedController, :index
    get "/infected/get", InfectedController, :getInfected
    end
end
