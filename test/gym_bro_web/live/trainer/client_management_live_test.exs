defmodule GymBroWeb.Trainer.ClientManagementLiveTest do
  use GymBroWeb.ConnCase, async: false

  import GymBro.AccountsFixtures
  import GymBro.BodyStatsFixtures
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias GymBro.{Profiles, Programs, Trainer, Training}

  defmodule FakeOpenAI do
    def send_request_to_openai(_context, prompt, _opts) do
      {:ok,
       if String.contains?(prompt, "6-week") do
         """
         {
           "program_name": "Regenerated Client Plan",
           "description": "A refreshed 6-week block built from trainer notes.",
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
                       "muscle_groups": ["chest", "back"],
                       "estimated_duration_min": 48,
                       "is_rest_day": false,
                       "exercises": [
                         {
                           "position": 1,
                           "name": "Machine Chest Press",
                           "sets": 3,
                           "reps": "10-12",
                           "rest_seconds": 75,
                           "weight_kg": 35,
                           "notes": "Smooth control through the bottom."
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
                       "muscle_groups": ["glutes", "quads"],
                       "estimated_duration_min": 48,
                       "is_rest_day": false,
                       "exercises": [
                         {
                           "position": 1,
                           "name": "Heel Elevated Squat",
                           "sets": 3,
                           "reps": "10-12",
                           "rest_seconds": 75,
                           "weight_kg": 30,
                           "notes": "Stay tall and smooth."
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
           "program_name": "Regenerated Client Plan",
           "description": "A refreshed block built from trainer notes.",
           "phases": [
             {
               "phase": 1,
               "name": "Foundation",
               "weeks": [1],
               "weeks_data": [
                 {
                   "week": 1,
                   "days": [
                     {
                       "day": 1,
                       "label": "Upper",
                       "type": "upper",
                       "muscle_groups": ["chest", "back"],
                       "estimated_duration_min": 48,
                       "is_rest_day": false,
                       "exercises": [
                         {
                           "position": 1,
                           "name": "Machine Chest Press",
                           "sets": 3,
                           "reps": "10-12",
                           "rest_seconds": 75,
                           "weight_kg": 35,
                           "notes": "Smooth control through the bottom."
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
       end}
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

  test "client list supports search", %{conn: conn} do
    trainer = trainer_user_with_profile()
    casey = user_fixture(%{email: "casey.client@example.com"})
    jamie = user_fixture(%{email: "jamie.stale@example.com"})

    Profiles.upsert_user_profile(casey.id, athlete_profile_attrs(%{goal: "muscle_gain"}))
    Profiles.upsert_user_profile(jamie.id, athlete_profile_attrs(%{goal: "weight_loss"}))

    Trainer.create_trainer_client(%{trainer_id: trainer.id, client_id: casey.id, status: "active"})

    Trainer.create_trainer_client(%{trainer_id: trainer.id, client_id: jamie.id, status: "paused"})

    conn = log_in_user(conn, trainer)
    {:ok, view, html} = live(conn, ~p"/trainer/clients")

    assert html =~ "Casey Client"
    assert html =~ "Jamie Stale"

    filtered_html =
      view
      |> form("#client-search-form", %{search: %{query: "casey"}})
      |> render_change()

    assert filtered_html =~ "Casey Client"
    refute filtered_html =~ "Jamie Stale"
  end

  test "trainer can send a client invitation", %{conn: conn} do
    trainer = trainer_user_with_profile()

    conn = log_in_user(conn, trainer)
    {:ok, view, html} = live(conn, ~p"/trainer/clients/invite")

    assert html =~ "Client invite"

    submit_html =
      view
      |> form("#client-invitation-form", %{client_invitation: %{email: "new.client@example.com"}})
      |> render_submit()

    assert submit_html =~ "Invitation sent."
    assert [%{email: "new.client@example.com"}] = Trainer.list_client_invitations(trainer.id)

    assert_email_sent(fn email ->
      email.subject == "You've been invited to train on GymBro" and
        email.text_body =~ "/join/"
    end)
  end

  test "client detail supports tabs, exercise editing, and ai regeneration", %{conn: conn} do
    trainer = trainer_user_with_profile()
    client = user_fixture(%{email: "casey.client@example.com"})

    {:ok, _profile} = Profiles.upsert_user_profile(client.id, athlete_profile_attrs())

    {:ok, _relationship} =
      Trainer.create_trainer_client(%{
        trainer_id: trainer.id,
        client_id: client.id,
        status: "active",
        notes: "Needs shoulder-friendly pressing."
      })

    body_weight_log_fixture(%{
      logged_at: ~D[2026-05-08],
      user_id: client.id,
      weight_kg: 80.0
    })

    body_weight_log_fixture(%{
      logged_at: ~D[2026-05-09],
      user_id: client.id,
      weight_kg: 79.4
    })

    checkin_image_fixture(%{
      image_type: "checkin",
      logged_at: ~D[2026-05-09],
      user_id: client.id
    })

    checkin_image_fixture(%{
      image_type: "progress",
      logged_at: ~D[2026-05-09],
      user_id: client.id,
      image_url: "https://example.com/progress.jpg"
    })

    personal_record_fixture(%{
      achieved_at: ~D[2026-05-09],
      exercise_name: "Bench Press",
      reps: 5,
      user_id: client.id,
      weight_kg: 100.0
    })

    {:ok, program} =
      Programs.create_program(%{
        ai_raw_plan: %{},
        created_by_id: trainer.id,
        current_phase: 1,
        current_week: 1,
        description: "Current coached block",
        name: "Build Block",
        phase_name: "Foundation",
        source: "trainer",
        status: "active",
        total_weeks: 12,
        user_id: client.id
      })

    {:ok, workout_day} =
      Programs.create_workout_day(%{
        day_label: "Upper",
        day_number: 1,
        estimated_duration_min: 55,
        is_rest_day: false,
        muscle_groups: ["chest", "back"],
        program_id: program.id,
        trainer_notes: "Keep all pressing pain-free.",
        week_number: 1,
        workout_type: "upper"
      })

    {:ok, exercise} =
      Programs.create_exercise(%{
        name: "Incline Dumbbell Press",
        notes: "Keep your shoulder blades pinned.",
        position: 1,
        reps: "8-10",
        rest_seconds: 90,
        sets: 4,
        trainer_notes: "Leave one rep in reserve.",
        weight_kg: 24.0,
        workout_day_id: workout_day.id
      })

    {:ok, session} =
      Training.create_workout_session(%{
        started_at: ~U[2026-05-09 06:30:00Z],
        status: "active",
        user_id: client.id,
        workout_day_id: workout_day.id
      })

    {:ok, _first_log} =
      Training.log_exercise_set(session, exercise, %{
        reps_completed: 10,
        rpe: 8,
        weight_kg: 24.0
      })

    conn = log_in_user(conn, trainer)
    {:ok, view, html} = live(conn, ~p"/trainer/clients/#{client.id}")

    assert html =~ "Client file"
    assert html =~ "Weight trend"
    assert html =~ "Live session"
    assert html =~ "Read-only live view"
    assert html =~ "Set 1"
    assert html =~ "10 reps"

    photos_html =
      view
      |> element("button[phx-value-tab='photos']")
      |> render_click()

    assert photos_html =~ "visible uploads"
    assert photos_html =~ "milestone photos"

    prs_html =
      view
      |> element("button[phx-value-tab='prs']")
      |> render_click()

    assert prs_html =~ "Bench Press"
    assert prs_html =~ "100.0 kg"

    program_html =
      view
      |> element("button[phx-value-tab='program']")
      |> render_click()

    assert program_html =~ "Build Block"
    assert program_html =~ "Incline Dumbbell Press"

    view
    |> element("button[phx-click='show_add_exercise'][phx-value-day_id='#{workout_day.id}']")
    |> render_click()

    add_html =
      view
      |> form("#trainer-exercise-form", %{
        exercise: %{
          name: "Chest Supported Row",
          notes: "Brace the chest into the pad.",
          reps: "10-12",
          rest_seconds: "75",
          sets: "3",
          trainer_notes: "Own the squeeze.",
          weight_kg: "20.0"
        }
      })
      |> render_submit()

    assert add_html =~ "Chest Supported Row"

    view
    |> element("button[phx-click='show_edit_exercise'][phx-value-exercise_id='#{exercise.id}']")
    |> render_click()

    edit_html =
      view
      |> form("#trainer-exercise-form", %{
        exercise: %{
          name: "Incline Dumbbell Press",
          notes: "Use a slower eccentric.",
          reps: "10-12",
          rest_seconds: "90",
          sets: "3",
          trainer_notes: "Deload the final set.",
          weight_kg: "22.5"
        }
      })
      |> render_submit()

    assert edit_html =~ "Override saved"
    assert edit_html =~ "Deload the final set."

    {:ok, _second_log} =
      Training.log_exercise_set(session, exercise, %{
        reps_completed: 8,
        rpe: 9,
        weight_kg: 22.5
      })

    updated_live_html = render(view)

    assert updated_live_html =~ "Set 2"
    assert updated_live_html =~ "22.5 kg"

    remove_html =
      view
      |> element("button[phx-click='remove_exercise'][phx-value-exercise_id='#{exercise.id}']")
      |> render_click()

    assert remove_html =~ "Exercise removed from the day."

    add_message_html =
      view
      |> form("#live-message-form", %{
        live_message: %{message: "Stay stacked and own the last two reps."}
      })
      |> render_submit()

    assert add_message_html =~ "Coach note sent."

    view
    |> form("#regeneration-form", %{
      regeneration: %{
        block_weeks: "6",
        trainer_notes: "Reduce pressing volume and keep sessions under 50 minutes."
      }
    })
    |> render_submit()

    regenerated_html = render_async(view)
    {:ok, detail} = Trainer.get_managed_client_detail(trainer.id, client.id)

    assert regenerated_html =~ "Regenerated Client Plan"
    assert regenerated_html =~ "Machine Chest Press"
    assert detail.program.total_weeks == 6
  end

  defp trainer_user_with_profile do
    trainer = user_fixture(%{role: "trainer"})

    {:ok, _profile} =
      Profiles.upsert_trainer_profile(trainer.id, %{
        bio: "High-accountability coaching",
        certification: "NASM",
        max_clients: 20,
        specialization: "strength",
        years_experience: 5
      })

    trainer
  end

  defp athlete_profile_attrs(overrides \\ %{}) do
    Enum.into(overrides, %{
      age: 28,
      days_per_week: 4,
      equipment: "gym",
      fitness_level: "intermediate",
      goal: "muscle_gain",
      goal_weight_kg: 84.0,
      height_cm: 176.0,
      onboarding_complete: true,
      preferred_block_weeks: 9,
      weight_kg: 80.0
    })
  end
end
