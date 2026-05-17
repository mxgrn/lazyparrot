defmodule LazyparrotWeb.Router do
  use LazyparrotWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LazyparrotWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :telegram do
    plug :accepts, ["json"]
    plug Gramex.UserDataPlug, halt_if_nil: true
    plug Gramex.UserDataPersistencePlug, repo: Lazyparrot.Repo, schema: Lazyparrot.Users.User
    plug LazyparrotWeb.Plugs.TelegramLocalePlug
  end

  scope "/", LazyparrotWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", LazyparrotWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  scope "/telegram", LazyparrotWeb do
    pipe_through :telegram

    post "/", TelegramController, :webhook
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:lazyparrot, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LazyparrotWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
