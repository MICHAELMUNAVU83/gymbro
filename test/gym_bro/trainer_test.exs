defmodule GymBro.TrainerTest do
  use GymBro.DataCase

  alias GymBro.{Profiles, Programs, Repo}
  alias GymBro.Trainer

  import GymBro.AccountsFixtures
  import GymBro.TrainerFixtures
  import Swoosh.TestAssertions

  defmodule FakeOpenAI do
    def send_request_to_openai(_context, prompt, _opts) do
      {:ok,
       if String.contains?(prompt, "6-week") do
         """
         {
           "program_name": "Trainer Refresh Block",
           "description": "A coached 6-week reset built from trainer notes.",
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
                       "estimated_duration_min": 50,
                       "is_rest_day": false,
                       "exercises": [
                         {
                           "position": 1,
                           "name": "Machine Chest Press",
                           "sets": 3,
                           "reps": "10-12",
                           "rest_seconds": 75,
                           "weight_kg": 35,
                           "notes": "Stay smooth through the bottom."
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
                       "estimated_duration_min": 50,
                       "is_rest_day": false,
                       "exercises": [
                         {
                           "position": 1,
                           "name": "Heel Elevated Squat",
                           "sets": 3,
                           "reps": "10-12",
                           "rest_seconds": 75,
                           "weight_kg": 30,
                           "notes": "Stay smooth through the bottom."
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
           "program_name": "Trainer Refresh Block",
           "description": "A coached reset built from trainer notes.",
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
                       "estimated_duration_min": 50,
                       "is_rest_day": false,
                       "exercises": [
                         {
                           "position": 1,
                           "name": "Machine Chest Press",
                           "sets": 3,
                           "reps": "10-12",
                           "rest_seconds": 75,
                           "weight_kg": 35,
                           "notes": "Stay smooth through the bottom."
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

  describe "trainer clients" do
    test "lists and fetches relationships for a trainer" do
      relationship = trainer_client_fixture()

      assert [fetched] = Trainer.list_trainer_clients(relationship.trainer_id)
      assert fetched.id == relationship.id

      assert Trainer.get_trainer_client(relationship.trainer_id, relationship.client_id).id ==
               relationship.id
    end

    test "rejects linking a trainer to themselves" do
      trainer = user_fixture(%{role: "trainer"})

      assert {:error, changeset} =
               Trainer.create_trainer_client(%{
                 trainer_id: trainer.id,
                 client_id: trainer.id,
                 status: "active"
               })

      assert "must be different from the trainer" in errors_on(changeset).client_id
    end

    test "verifies active client access" do
      relationship = trainer_client_fixture()

      assert :ok =
               Trainer.verify_client_access(relationship.trainer_id, relationship.client_id)
    end

    test "rejects client access when the relationship is not active" do
      relationship = trainer_client_fixture(%{status: "paused"})

      assert {:error, :unauthorized} =
               Trainer.verify_client_access(relationship.trainer_id, relationship.client_id)
    end

    test "lists managed clients and filters by a search string" do
      trainer = user_fixture(%{role: "trainer"})
      casey = user_fixture(%{email: "casey.client@example.com"})
      jamie = user_fixture(%{email: "jamie.stale@example.com"})

      Profiles.upsert_user_profile(casey.id, %{
        age: 28,
        days_per_week: 4,
        equipment: "gym",
        fitness_level: "intermediate",
        goal: "muscle_gain",
        goal_weight_kg: 84.0,
        height_cm: 176.0,
        onboarding_complete: true,
        weight_kg: 80.0
      })

      Profiles.upsert_user_profile(jamie.id, %{
        age: 31,
        days_per_week: 5,
        equipment: "gym",
        fitness_level: "advanced",
        goal: "weight_loss",
        goal_weight_kg: 74.0,
        height_cm: 172.0,
        onboarding_complete: true,
        weight_kg: 79.0
      })

      Trainer.create_trainer_client(%{
        trainer_id: trainer.id,
        client_id: casey.id,
        status: "active"
      })

      Trainer.create_trainer_client(%{
        trainer_id: trainer.id,
        client_id: jamie.id,
        status: "paused"
      })

      assert [%{display_name: "Casey Client"}, %{display_name: "Jamie Stale"}] =
               Trainer.list_managed_clients(trainer.id)

      assert [%{email: "casey.client@example.com"}] =
               Trainer.list_managed_clients(trainer.id, "casey client")

      assert [%{email: "jamie.stale@example.com"}] =
               Trainer.list_managed_clients(trainer.id, "jamie")
    end
  end

  describe "client invitations" do
    test "issues a pending invitation with a token and expiry" do
      trainer = user_fixture(%{role: "trainer"})

      assert {:ok, invitation} =
               Trainer.issue_client_invitation(trainer.id, "newclient@example.com")

      assert invitation.status == "pending"
      assert invitation.token
      assert invitation.expires_at
      assert Trainer.get_client_invitation_by_token(invitation.token).id == invitation.id
    end

    test "delivers an invitation email and accepts it for an existing athlete" do
      trainer = user_fixture(%{role: "trainer"})
      athlete = user_fixture(%{email: "invited.athlete@example.com"})

      assert {:ok, invitation} =
               Trainer.deliver_client_invitation(
                 trainer,
                 %{email: athlete.email},
                 fn token -> "https://example.com/join/#{token}" end
               )

      assert_email_sent(fn email ->
        email.subject == "You've been invited to train on GymBro" and
          email.text_body =~ trainer.email and
          email.text_body =~ invitation.token
      end)

      assert {:ok, trainer_client} = Trainer.accept_client_invitation(invitation.token, athlete)
      assert trainer_client.trainer_id == trainer.id
      assert trainer_client.client_id == athlete.id
      assert Trainer.get_client_invitation_by_token(invitation.token).status == "accepted"
    end

    test "registers an invited client and creates the trainer relationship" do
      trainer = user_fixture(%{role: "trainer"})

      assert {:ok, invitation} =
               Trainer.issue_client_invitation(trainer.id, "fresh.client@example.com")

      assert {:ok, user} =
               Trainer.register_invited_client(
                 valid_user_attributes(password: valid_user_password()),
                 invitation.token
               )

      assert user.email == "fresh.client@example.com"
      assert user.role == "athlete"
      assert Trainer.get_trainer_client(trainer.id, user.id)
      assert Trainer.get_client_invitation_by_token(invitation.token).status == "accepted"
    end
  end

  describe "exercise overrides" do
    test "lists active overrides for a client" do
      override = trainer_exercise_override_fixture()

      assert [fetched] = Trainer.list_trainer_exercise_overrides_for_client(override.client_id)
      assert fetched.id == override.id
    end

    test "adds, updates, and removes exercises for an active client" do
      trainer = user_fixture(%{role: "trainer"})
      client = user_fixture()

      {:ok, _profile} =
        Profiles.upsert_user_profile(client.id, %{
          age: 29,
          days_per_week: 4,
          equipment: "gym",
          fitness_level: "intermediate",
          goal: "muscle_gain",
          goal_weight_kg: 83.0,
          height_cm: 177.0,
          onboarding_complete: true,
          weight_kg: 79.5
        })

      {:ok, _relationship} =
        Trainer.create_trainer_client(%{
          trainer_id: trainer.id,
          client_id: client.id,
          status: "active"
        })

      {:ok, program} =
        Programs.create_program(%{
          ai_raw_plan: %{},
          created_by_id: trainer.id,
          current_phase: 1,
          current_week: 1,
          description: "Coached hypertrophy block",
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
          week_number: 1,
          workout_type: "upper"
        })

      assert {:ok, first_exercise} =
               Trainer.add_exercise_to_client_day(trainer.id, client.id, workout_day.id, %{
                 "name" => "Incline Dumbbell Press",
                 "notes" => "Keep your shoulder blades pinned.",
                 "reps" => "8-10",
                 "rest_seconds" => "90",
                 "sets" => "4",
                 "trainer_notes" => "Leave one rep in reserve.",
                 "weight_kg" => "24.0"
               })

      assert first_exercise.position == 1

      assert {:ok, second_exercise} =
               Trainer.add_exercise_to_client_day(trainer.id, client.id, workout_day.id, %{
                 "name" => "Chest Supported Row",
                 "reps" => "10-12",
                 "sets" => "3"
               })

      assert {:ok, updated_exercise} =
               Trainer.update_client_exercise(trainer.id, client.id, first_exercise.id, %{
                 "notes" => "Use a slower eccentric.",
                 "reps" => "10-12",
                 "sets" => "3",
                 "trainer_notes" => "Deload the last set.",
                 "weight_kg" => "22.5"
               })

      assert updated_exercise.sets == 3
      assert updated_exercise.reps == "10-12"
      assert updated_exercise.weight_kg == 22.5
      assert updated_exercise.trainer_notes == "Deload the last set."

      assert [override] =
               Trainer.list_trainer_exercise_overrides_for_client(client.id, trainer.id)

      assert override.exercise_id == updated_exercise.id
      assert override.sets == 3
      assert override.reps == "10-12"
      assert override.weight_kg == 22.5

      assert :ok = Trainer.remove_client_exercise(trainer.id, client.id, first_exercise.id)

      assert [%{id: remaining_id, position: 1}] =
               Programs.list_exercises_for_workout_day(workout_day.id)

      assert remaining_id == second_exercise.id
    end
  end

  describe "program regeneration" do
    test "replaces the active program with an ai trainer edited version" do
      original_openai_client = Application.get_env(:gym_bro, :openai_client)
      Application.put_env(:gym_bro, :openai_client, FakeOpenAI)

      on_exit(fn ->
        if original_openai_client do
          Application.put_env(:gym_bro, :openai_client, original_openai_client)
        else
          Application.delete_env(:gym_bro, :openai_client)
        end
      end)

      trainer = user_fixture(%{role: "trainer"})
      client = user_fixture()

      {:ok, _profile} =
        Profiles.upsert_user_profile(client.id, %{
          age: 30,
          days_per_week: 4,
          equipment: "gym",
          fitness_level: "intermediate",
          goal: "muscle_gain",
          goal_weight_kg: 84.0,
          height_cm: 178.0,
          onboarding_complete: true,
          preferred_block_weeks: 9,
          weight_kg: 80.0
        })

      {:ok, _relationship} =
        Trainer.create_trainer_client(%{
          trainer_id: trainer.id,
          client_id: client.id,
          status: "active"
        })

      {:ok, existing_program} =
        Programs.create_program(%{
          ai_raw_plan: %{},
          created_by_id: trainer.id,
          current_phase: 1,
          current_week: 1,
          description: "Original coached block",
          name: "Existing Plan",
          phase_name: "Foundation",
          source: "trainer",
          status: "active",
          total_weeks: 12,
          user_id: client.id
        })

      assert {:ok, regenerated_program} =
               Trainer.regenerate_client_program(
                 trainer.id,
                 client.id,
                 "Lower axial loading and keep sessions under 50 minutes.",
                 %{block_weeks: 6}
               )

      assert regenerated_program.id != existing_program.id
      assert regenerated_program.status == "active"
      assert regenerated_program.source == "ai_trainer_edited"
      assert regenerated_program.ai_raw_plan["program_name"] == "Trainer Refresh Block"
      assert regenerated_program.total_weeks == 6
      assert length(regenerated_program.workout_days) == 6
      assert Repo.reload(existing_program).status == "paused"
    end
  end
end
