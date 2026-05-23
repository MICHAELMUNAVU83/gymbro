defmodule GymBroWeb.OnboardingLiveTest do
  use GymBroWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import GymBro.AccountsFixtures

  alias GymBro.{Profiles, Programs}

  defmodule FakeOpenAI do
    def send_request_to_openai(_context, _prompt, _opts) do
      {:ok,
       """
       {
         "program_name": "Starter Muscle Gain Plan",
         "description": "A 9-week plan for building muscle with balanced recovery.",
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
                     "estimated_duration_min": 60,
                     "is_rest_day": false,
                     "exercises": [
                       {
                         "position": 1,
                         "name": "Incline Dumbbell Press",
                         "sets": 4,
                         "reps": "8-10",
                         "rest_seconds": 90,
                         "weight_kg": 24,
                         "notes": "Keep your shoulder blades pinned.",
                         "is_timed": false,
                         "duration_seconds": null
                       }
                     ]
                   },
                   {
                     "day": 2,
                     "label": "Rest",
                     "type": "rest",
                     "is_rest_day": true,
                     "muscle_groups": [],
                     "exercises": []
                   }
                 ]
               }
             ]
           }
         ]
       }
       """}
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

  describe "athlete onboarding" do
    test "welcome screen renders for a new athlete", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      {:ok, _view, html} = live(conn, ~p"/onboarding/welcome")

      assert html =~ "shape your first plan"
      assert html =~ "What we&#39;ll set up"
      assert html =~ "Generate your athlete profile"
    end

    test "body stats step saves the first onboarding data", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/onboarding/body-stats")

      view
      |> form("#body-stats-form", %{
        profile: %{
          age: "29",
          height_cm: "178",
          weight_kg: "79.5"
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/onboarding/goals")

      profile = Profiles.get_user_profile_by_user(user.id)
      assert profile.age == 29
      assert profile.height_cm == 178.0
      assert profile.weight_kg == 79.5
    end

    test "generating step completes onboarding and redirects home", %{conn: conn} do
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
          preferred_session_minutes: 60,
          weight_kg: 79.5
        })

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/onboarding/generating")

      assert html =~ "Generating your plan"
      Process.sleep(250)
      assert_redirect(view, ~p"/")

      assert Profiles.get_user_profile_by_user(user.id).onboarding_complete
      assert [program] = Programs.list_programs_for_user(user.id)
      assert program.status == "active"
      assert program.ai_raw_plan["program_name"] == "Starter Muscle Gain Plan"

      assert [workout_day | _rest] = Programs.list_workout_days_for_program(program.id)
      assert workout_day.day_label == "Upper"
    end

    test "goals step saves schedule and time per day", %{conn: conn} do
      user = user_fixture()

      {:ok, _profile} =
        Profiles.upsert_user_profile(user.id, %{
          age: 29,
          height_cm: 178.0,
          weight_kg: 79.5
        })

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/onboarding/goals")

      view
      |> form("#goals-form", %{
        profile: %{
          days_per_week: "4",
          equipment: "gym",
          fitness_level: "intermediate",
          goal: "muscle_gain",
          goal_weight_kg: "82.0",
          preferred_exercises_per_day: "4",
          preferred_rest_days: ["3", "6", "7"],
          preferred_session_minutes: "60"
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/onboarding/generating")

      profile = Profiles.get_user_profile_by_user(user.id)
      assert profile.days_per_week == 4
      assert profile.preferred_exercises_per_day == 4
      assert profile.preferred_rest_days == [3, 6, 7]
      assert profile.preferred_session_minutes == 60
    end
  end

  describe "trainer onboarding" do
    test "trainer setup saves the trainer profile and opens the dashboard", %{conn: conn} do
      trainer = user_fixture(%{role: "trainer"})
      conn = log_in_user(conn, trainer)

      {:ok, view, _html} = live(conn, ~p"/onboarding/trainer-setup")

      view
      |> form("#trainer-setup-form", %{
        trainer_profile: %{
          bio: "Strength-focused coach",
          certification: "NASM-CPT",
          max_clients: "18",
          specialization: "strength",
          years_experience: "6"
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/trainer")

      profile = Profiles.get_trainer_profile_by_user(trainer.id)
      assert profile.specialization == "strength"
      assert profile.max_clients == 18
      assert profile.years_experience == 6
    end
  end
end
