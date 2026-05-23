defmodule GymBroWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """
  use GymBroWeb, :html

  embed_templates "layouts/*"

  def athlete_nav_items do
    [
      %{key: :home, label: "Home", path: ~p"/home", icon: "hero-home", action: :navigate},
      %{
        key: :workouts,
        label: "Workouts",
        path: ~p"/workouts",
        icon: "hero-fire",
        action: :navigate
      },
      %{
        key: :body_stats,
        label: "Body stats",
        path: ~p"/body-stats",
        icon: "hero-chart-bar",
        action: :navigate
      },
      %{
        key: :settings,
        label: "Settings",
        path: ~p"/settings",
        icon: "hero-cog-6-tooth",
        action: :navigate
      },
      %{
        key: :logout,
        label: "Logout",
        path: ~p"/users/log_out",
        icon: "hero-arrow-left-on-rectangle",
        action: :href,
        method: "delete"
      }
    ]
  end

  def trainer_nav_items do
    [
      %{
        key: :dashboard,
        label: "Dashboard",
        path: ~p"/trainer",
        icon: "hero-home",
        action: :navigate
      },
      %{
        key: :clients,
        label: "Clients",
        path: ~p"/trainer/clients",
        icon: "hero-users",
        action: :navigate
      },
      %{
        key: :invite,
        label: "Invite",
        path: ~p"/trainer/clients/invite",
        icon: "hero-user-plus",
        action: :navigate
      },
      %{
        key: :analytics,
        label: "Analytics",
        path: ~p"/trainer/analytics",
        icon: "hero-chart-pie",
        action: :navigate
      },
      %{
        key: :logout,
        label: "Logout",
        path: ~p"/users/log_out",
        icon: "hero-arrow-left-on-rectangle",
        action: :href,
        method: "delete"
      }
    ]
  end

  def nav_item_class(_role, key, active_nav) do
    if nav_active?(key, active_nav) do
      "gb-tab gb-tab--active"
    else
      "gb-tab"
    end
  end

  def nav_icon_class(_role, _key, _active_nav) do
    "gb-tab__icon"
  end

  defp nav_active?(key, active_nav), do: to_string(key) == to_string(active_nav)
end
