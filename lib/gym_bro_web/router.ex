defmodule GymBroWeb.Router do
  use GymBroWeb, :router

  import GymBroWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GymBroWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GymBroWeb do
    pipe_through :browser

    live_session :public, on_mount: [{GymBroWeb.UserAuth, :mount_current_user}] do
      live "/", HomeLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", GymBroWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:gym_bro, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GymBroWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", GymBroWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{GymBroWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/join/role", Auth.RoleSelectLive, :new
    end

    post "/join/role", RoleSelectionController, :create
    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", GymBroWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/", GymBroWeb do
    pipe_through [:browser]

    get "/join/:token", ClientInvitationController, :show

    live_session :authenticated,
      on_mount: [{GymBroWeb.UserAuth, :ensure_authenticated}] do
      live "/onboarding/welcome", Onboarding.WelcomeLive, :index
      live "/onboarding/body-stats", Onboarding.BodyStatsLive, :index
      live "/onboarding/goals", Onboarding.GoalsLive, :index
      live "/onboarding/generating", Onboarding.GeneratingLive, :index
      live "/onboarding/trainer-setup", Onboarding.TrainerSetupLive, :index
    end

    live_session :trainer_authenticated,
      on_mount: [
        {GymBroWeb.UserAuth, :ensure_authenticated},
        {GymBroWeb.RequireTrainer, :default}
      ] do
      live "/trainer", Trainer.DashboardLive, :index
      live "/trainer/analytics", Trainer.AnalyticsLive, :index
      live "/trainer/clients", Trainer.ClientListLive, :index
      live "/trainer/clients/invite", Trainer.ClientInviteLive, :index
      live "/trainer/clients/:client_id", Trainer.ClientDetailLive, :show
    end

    live_session :athlete_authenticated,
      on_mount: [
        {GymBroWeb.UserAuth, :ensure_authenticated},
        {GymBroWeb.RequireAthlete, :default}
      ] do
      live "/home", Athlete.HomeLive, :index
      live "/settings", Athlete.SettingsLive, :index
      live "/workouts", Athlete.WorkoutListLive, :index
      live "/workouts/session/:session_id", Athlete.ActiveWorkoutLive, :show
      live "/workouts/:id", Athlete.WorkoutDetailLive, :show
      live "/body-stats", Athlete.BodyStatsLive, :index
    end
  end

  scope "/", GymBroWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end
end
