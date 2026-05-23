defmodule GymBro.ProgramsTest do
  use GymBro.DataCase

  alias GymBro.{Profiles, Programs}

  import GymBro.AccountsFixtures
  import GymBro.ProgramsFixtures

  defmodule ShortWeekOpenAI do
    def send_request_to_openai(_context, _prompt, _opts) do
      {:ok,
       """
       {
         "program_name": "11-Week Weight Loss",
         "description": "Intermediate gym plan for weight loss",
         "phases": [
           {
             "phase": 1,
             "name": "Fat Loss Focus",
             "weeks": [1, 2, 3, 4],
             "weeks_data": [
               {
                 "week": 1,
                 "days": [
                   {
                     "day": 1,
                     "label": "Upper",
                     "type": "upper",
                     "estimated_duration_min": 90,
                     "is_rest_day": false,
                     "exercises": [
                       {
                         "position": 1,
                         "name": "Bench Press",
                         "sets": 4,
                         "reps": "8-10",
                         "rest_seconds": 90,
                         "visual_guide": "Chest tall, drive bar up"
                       }
                     ]
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

  describe "programs" do
    test "lists a user's programs and finds the active one" do
      program = program_fixture()

      assert [fetched] = Programs.list_programs_for_user(program.user_id)
      assert fetched.id == program.id
      assert Programs.get_active_program_for_user(program.user_id).id == program.id
    end

    test "finds the next unfinished workout for an athlete" do
      athlete = GymBro.AccountsFixtures.user_fixture()

      {:ok, program} =
        Programs.create_program(%{
          ai_raw_plan: %{"weeks" => 12},
          created_by_id: athlete.id,
          current_phase: 1,
          current_week: 1,
          description: "Hypertrophy block",
          name: "Build Phase",
          phase_name: "Foundation",
          source: "ai",
          status: "active",
          total_weeks: 12,
          user_id: athlete.id
        })

      {:ok, completed_day} =
        Programs.create_workout_day(%{
          day_label: "Push",
          day_number: 1,
          estimated_duration_min: 55,
          is_rest_day: false,
          muscle_groups: ["chest"],
          program_id: program.id,
          week_number: 1,
          workout_type: "push"
        })

      {:ok, upcoming_day} =
        Programs.create_workout_day(%{
          day_label: "Legs",
          day_number: 2,
          estimated_duration_min: 65,
          is_rest_day: false,
          muscle_groups: ["quads", "glutes"],
          program_id: program.id,
          trainer_notes: "Own the tempo.",
          week_number: 1,
          workout_type: "legs"
        })

      {:ok, _exercise} =
        Programs.create_exercise(%{
          name: "Back Squat",
          position: 1,
          reps: "6-8",
          rest_seconds: 120,
          sets: 4,
          workout_day_id: upcoming_day.id
        })

      {:ok, _session} =
        GymBro.Training.create_workout_session(%{
          completed_at: ~U[2026-05-07 10:30:00Z],
          duration_seconds: 2_700,
          started_at: ~U[2026-05-07 09:45:00Z],
          status: "completed",
          user_id: athlete.id,
          workout_day_id: completed_day.id
        })

      assert %{day_label: "Legs", exercise_count: 1} =
               Programs.get_next_workout_for_user(athlete.id)
    end

    test "imports a parsed AI plan with workout days, exercises, and raw JSON" do
      athlete = GymBro.AccountsFixtures.user_fixture()

      assert {:ok, program} =
               Programs.import_ai_plan(athlete.id, athlete.id, parsed_ai_plan(), %{
                 status: "active"
               })

      assert program.user_id == athlete.id
      assert program.created_by_id == athlete.id
      assert program.status == "active"
      assert program.ai_raw_plan["program_name"] == "Lean Strength Block"

      assert [workout_day | _] = Programs.list_workout_days_for_program(program.id)
      assert workout_day.day_label == "Push"

      assert [exercise | _] = Programs.list_exercises_for_workout_day(workout_day.id)
      assert exercise.name == "Bench Press"
    end

    test "regeneration honors requested block weeks when ai returns too few weeks" do
      original_openai_client = Application.get_env(:gym_bro, :openai_client)
      Application.put_env(:gym_bro, :openai_client, ShortWeekOpenAI)

      on_exit(fn ->
        if original_openai_client do
          Application.put_env(:gym_bro, :openai_client, original_openai_client)
        else
          Application.delete_env(:gym_bro, :openai_client)
        end
      end)

      athlete = user_fixture()

      {:ok, _profile} =
        Profiles.upsert_user_profile(athlete.id, %{
          age: 29,
          days_per_week: 4,
          equipment: "gym",
          fitness_level: "intermediate",
          goal: "weight_loss",
          goal_weight_kg: 75.0,
          height_cm: 178.0,
          onboarding_complete: true,
          preferred_block_weeks: 11,
          preferred_exercises_per_day: 4,
          preferred_rest_days: [2, 5, 7],
          preferred_session_minutes: 60,
          weight_kg: 81.0
        })

      assert {:ok, program} =
               Programs.regenerate_ai_program_for_user(athlete.id, athlete.id)

      assert program.total_weeks == 11
      assert length(program.workout_days) == 11
      assert Enum.uniq(Enum.map(program.workout_days, & &1.week_number)) == Enum.to_list(1..11)
      assert program.ai_raw_plan["phases"] |> Enum.flat_map(& &1["weeks"]) == Enum.to_list(1..11)
    end
  end

  describe "workout days and exercises" do
    test "lists workout days for a program and exercises for a workout day" do
      workout_day = workout_day_fixture()
      exercise = exercise_fixture(%{workout_day_id: workout_day.id})

      assert [fetched_day] = Programs.list_workout_days_for_program(workout_day.program_id)
      assert fetched_day.id == workout_day.id

      assert [fetched_exercise] = Programs.list_exercises_for_workout_day(workout_day.id)
      assert fetched_exercise.id == exercise.id
    end

    test "lists active workout days for a user and fetches a scoped workout day" do
      athlete = GymBro.AccountsFixtures.user_fixture()

      {:ok, active_program} =
        Programs.create_program(%{
          ai_raw_plan: %{},
          created_by_id: athlete.id,
          current_phase: 1,
          current_week: 1,
          phase_name: "Foundation",
          source: "ai",
          status: "active",
          total_weeks: 12,
          user_id: athlete.id
        })

      {:ok, archived_program} =
        Programs.create_program(%{
          ai_raw_plan: %{},
          created_by_id: athlete.id,
          current_phase: 1,
          current_week: 1,
          phase_name: "Foundation",
          source: "ai",
          status: "completed",
          total_weeks: 12,
          user_id: athlete.id
        })

      {:ok, active_day} =
        Programs.create_workout_day(%{
          day_label: "Upper",
          day_number: 1,
          estimated_duration_min: 55,
          program_id: active_program.id,
          week_number: 1,
          workout_type: "upper"
        })

      {:ok, _archived_day} =
        Programs.create_workout_day(%{
          day_label: "Archived",
          day_number: 1,
          estimated_duration_min: 45,
          program_id: archived_program.id,
          week_number: 1,
          workout_type: "upper"
        })

      assert [fetched_day] = Programs.list_workout_days_for_user(athlete.id)
      assert fetched_day.id == active_day.id
      assert Programs.get_workout_day_for_user!(athlete.id, active_day.id).id == active_day.id
    end
  end

  defp parsed_ai_plan do
    {:ok, parsed_plan} =
      GymBro.AI.PlanParser.parse("""
      {
        "program_name": "Lean Strength Block",
        "description": "A 12-week plan for building strength while leaning out.",
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
                    "label": "Push",
                    "type": "push",
                    "muscle_groups": ["chest", "shoulders", "triceps"],
                    "estimated_duration_min": 55,
                    "is_rest_day": false,
                    "exercises": [
                      {
                        "position": 1,
                        "name": "Bench Press",
                        "sets": 4,
                        "reps": "8-12",
                        "rest_seconds": 90,
                        "weight_kg": 60,
                        "notes": "Keep elbows at 45 degrees",
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
      """)

    parsed_plan
  end
end
