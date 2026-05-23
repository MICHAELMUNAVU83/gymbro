defmodule GymBroWeb.Athlete.BodyStatsLiveTest do
  use GymBroWeb.ConnCase, async: false

  import GymBro.AccountsFixtures
  import Phoenix.LiveViewTest

  alias GymBro.{BodyStats, Profiles}

  describe "athlete body stats" do
    test "logs weight and uploads a progress photo", %{conn: conn} do
      user = onboarded_athlete_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/body-stats")

      assert html =~ "Body stats"
      assert html =~ "Weight log"

      view
      |> form("#weight-log-form", %{
        body_weight_log: %{
          logged_at: "2026-05-10",
          notes: "Morning weigh-in",
          weight_kg: "78.4"
        }
      })
      |> render_submit()

      assert BodyStats.latest_body_weight_log(user.id).weight_kg == 78.4

      progress_upload =
        file_input(view, "#progress-upload-form", :progress_image, [
          %{
            last_modified: 1_715_000_000_000,
            name: "progress.jpg",
            content: "progress-image",
            size: byte_size("progress-image"),
            type: "image/jpeg"
          }
        ])

      assert render_upload(progress_upload, "progress.jpg") =~ "progress.jpg"

      view
      |> form("#progress-upload-form", %{
        progress_photo: %{
          logged_at: "2026-05-10",
          notes: "Week 4 comparison"
        }
      })
      |> render_submit()

      assert [_progress] = BodyStats.list_checkin_images_for_user_by_type(user.id, "progress")
      assert render(view) =~ "Photo timeline"
      assert render(view) =~ "Milestone gallery"
    end
  end

  defp onboarded_athlete_fixture do
    user = user_fixture()

    {:ok, _profile} =
      Profiles.upsert_user_profile(user.id, %{
        age: 29,
        days_per_week: 4,
        equipment: "gym",
        fitness_level: "intermediate",
        goal: "muscle_gain",
        goal_weight_kg: 82.0,
        height_cm: 178.0,
        onboarding_complete: true,
        weight_kg: 79.5
      })

    user
  end
end
