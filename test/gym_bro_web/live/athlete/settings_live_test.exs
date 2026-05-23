defmodule GymBroWeb.Athlete.SettingsLiveTest do
  use GymBroWeb.ConnCase, async: false

  import GymBro.AccountsFixtures
  import Phoenix.LiveViewTest

  alias GymBro.{Profiles, Programs}

  defmodule FakeOpenAI do
    def send_request_to_openai(_context, prompt, _opts) do
      {:ok, response_for(prompt)}
    end

    defp response_for(prompt) do
      if String.contains?(prompt, "12-week") do
        """
        {
          "program_name": "Fresh Twelve Week Block",
          "description": "A focused 12-week block refreshed from the latest athlete settings.",
          "phases": [
            {
              "phase": 1,
              "name": "Foundation",
              "weeks": [1, 2, 3, 4],
              "weeks_data": [
                {
                  "week": 1,
                  "days": [
                    {
                      "day": 1,
                      "label": "Upper",
                      "type": "upper",
                      "muscle_groups": ["chest", "back", "shoulders"],
                      "estimated_duration_min": 55,
                      "is_rest_day": false,
                      "exercises": [
                        {
                          "position": 1,
                          "name": "Machine Chest Press",
                          "sets": 4,
                          "reps": "8-10",
                          "rest_seconds": 75,
                          "weight_kg": 32.0,
                          "notes": "Own the bottom range."
                        }
                      ]
                    }
                  ]
                }
              ]
            },
            {
              "phase": 2,
              "name": "Build",
              "weeks": [5, 6, 7, 8],
              "weeks_data": [
                {
                  "week": 5,
                  "days": [
                    {
                      "day": 1,
                      "label": "Lower",
                      "type": "lower",
                      "muscle_groups": ["quads", "glutes"],
                      "estimated_duration_min": 60,
                      "is_rest_day": false,
                      "exercises": [
                        {
                          "position": 1,
                          "name": "Hack Squat",
                          "sets": 4,
                          "reps": "8-10",
                          "rest_seconds": 90,
                          "weight_kg": 70.0,
                          "notes": "Stay stacked through the mid-foot."
                        }
                      ]
                    }
                  ]
                }
              ]
            },
            {
              "phase": 3,
              "name": "Peak",
              "weeks": [9, 10, 11, 12],
              "weeks_data": [
                {
                  "week": 9,
                  "days": [
                    {
                      "day": 1,
                      "label": "Conditioning",
                      "type": "conditioning",
                      "muscle_groups": ["full_body"],
                      "estimated_duration_min": 42,
                      "is_rest_day": false,
                      "exercises": [
                        {
                          "position": 1,
                          "name": "Assault Bike Sprint",
                          "sets": 6,
                          "reps": "AMRAP",
                          "rest_seconds": 45,
                          "weight_kg": null,
                          "notes": "Hard efforts, full recovery."
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """
      else
        """
        {
          "program_name": "Fresh Nine Week Block",
          "description": "A focused 9-week block refreshed from the latest athlete settings.",
          "phases": [
            {
              "phase": 1,
              "name": "Foundation",
              "weeks": [1, 2, 3],
              "weeks_data": [
                {
                  "week": 1,
                  "days": [
                    {
                      "day": 1,
                      "label": "Upper",
                      "type": "upper",
                      "muscle_groups": ["chest", "back", "shoulders"],
                      "estimated_duration_min": 55,
                      "is_rest_day": false,
                      "exercises": [
                        {
                          "position": 1,
                          "name": "Machine Chest Press",
                          "sets": 4,
                          "reps": "8-10",
                          "rest_seconds": 75,
                          "weight_kg": 32.0,
                          "notes": "Own the bottom range."
                        }
                      ]
                    }
                  ]
                }
              ]
            },
            {
              "phase": 2,
              "name": "Build",
              "weeks": [4, 5, 6],
              "weeks_data": [
                {
                  "week": 4,
                  "days": [
                    {
                      "day": 1,
                      "label": "Lower",
                      "type": "lower",
                      "muscle_groups": ["quads", "glutes"],
                      "estimated_duration_min": 60,
                      "is_rest_day": false,
                      "exercises": [
                        {
                          "position": 1,
                          "name": "Hack Squat",
                          "sets": 4,
                          "reps": "8-10",
                          "rest_seconds": 90,
                          "weight_kg": 70.0,
                          "notes": "Stay stacked through the mid-foot."
                        }
                      ]
                    }
                  ]
                }
              ]
            },
            {
              "phase": 3,
              "name": "Peak",
              "weeks": [7, 8, 9],
              "weeks_data": [
                {
                  "week": 7,
                  "days": [
                    {
                      "day": 1,
                      "label": "Conditioning",
                      "type": "conditioning",
                      "muscle_groups": ["full_body"],
                      "estimated_duration_min": 42,
                      "is_rest_day": false,
                      "exercises": [
                        {
                          "position": 1,
                          "name": "Assault Bike Sprint",
                          "sets": 6,
                          "reps": "AMRAP",
                          "rest_seconds": 45,
                          "weight_kg": null,
                          "notes": "Hard efforts, full recovery."
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """
      end
    end
  end

  setup do
    original_openai_client = Application.get_env(:gym_bro, :openai_client)
    Application.put_env(:gym_bro, :openai_client, FakeOpenAI)

    on_exit(fn ->
      if original_openai_client do
        Application.put_env(:gym_bro, :openai_client, original_openai_client)
      else
        Application.delete_env(:gym_bro, :openai_client)
      end
    end)

    :ok
  end

  test "athlete can update training settings", %{conn: conn} do
    %{user: user} = athlete_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, html} = live(conn, ~p"/settings")

    assert html =~ "Tune the next training block."

    view
    |> form("#athlete-settings-form", %{
      profile: %{
        age: "31",
        days_per_week: "5",
        equipment: "home",
        fitness_level: "advanced",
        goal: "maintenance",
        goal_weight_kg: "81.0",
        height_cm: "180.0",
        preferred_block_weeks: "12",
        preferred_exercises_per_day: "5",
        preferred_rest_days: ["2", "6"],
        preferred_session_minutes: "75",
        weight_kg: "79.0"
      }
    })
    |> render_submit()

    profile = Profiles.get_user_profile_by_user(user.id)
    assert profile.age == 31
    assert profile.days_per_week == 5
    assert profile.equipment == "home"
    assert profile.goal == "maintenance"
    assert profile.preferred_block_weeks == 12
    assert profile.preferred_exercises_per_day == 5
    assert profile.preferred_rest_days == [2, 6]
    assert profile.preferred_session_minutes == 75
  end

  test "athlete can regenerate the active program from settings", %{conn: conn} do
    %{program: existing_program, user: user} = athlete_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, html} = live(conn, ~p"/settings")

    assert html =~ existing_program.name

    view
    |> form("#athlete-settings-form", %{
      profile: %{
        age: "29",
        days_per_week: "4",
        equipment: "gym",
        fitness_level: "intermediate",
        goal: "muscle_gain",
        goal_weight_kg: "82.0",
        height_cm: "178.0",
        preferred_block_weeks: "12",
        preferred_exercises_per_day: "4",
        preferred_rest_days: ["2", "5", "7"],
        preferred_session_minutes: "60",
        weight_kg: "79.5"
      }
    })
    |> render_change()

    view
    |> element("#regenerate-plan-button")
    |> render_click()

    regenerated_html = render_async(view)
    active_program = Programs.get_active_program_for_user(user.id)

    assert regenerated_html =~ "Fresh Twelve Week Block"
    assert active_program.name == "Fresh Twelve Week Block"
    assert active_program.total_weeks == 12
    assert active_program.source == "ai"
    assert Programs.get_program!(existing_program.id).status == "paused"
  end

  defp athlete_fixture do
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
        preferred_block_weeks: 9,
        preferred_exercises_per_day: 4,
        preferred_rest_days: [2, 5, 7],
        preferred_session_minutes: 60,
        weight_kg: 79.5
      })

    {:ok, program} =
      Programs.create_program(%{
        ai_raw_plan: %{"weeks" => 12},
        created_by_id: user.id,
        current_phase: 1,
        current_week: 1,
        description: "Current athlete block",
        name: "Build phase",
        phase_name: "Foundation",
        source: "ai",
        status: "active",
        total_weeks: 12,
        user_id: user.id
      })

    %{
      program: program,
      user: user
    }
  end
end
