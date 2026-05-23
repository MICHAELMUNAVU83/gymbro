defmodule GymBro.ProgramsFixtures do
  @moduledoc """
  Test helpers for the `GymBro.Programs` context.
  """

  import GymBro.AccountsFixtures

  def program_fixture(attrs \\ %{}) do
    athlete = user_fixture()
    creator = user_fixture(%{role: "trainer"})

    {:ok, program} =
      attrs
      |> Enum.into(%{
        ai_raw_plan: %{"weeks" => 12},
        created_by_id: creator.id,
        current_phase: 1,
        current_week: 1,
        description: "A structured 12-week hypertrophy block.",
        name: "Build Phase",
        phase_name: "Foundation",
        source: "ai",
        status: "active",
        total_weeks: 12,
        user_id: athlete.id
      })
      |> GymBro.Programs.create_program()

    program
  end

  def workout_day_fixture(attrs \\ %{}) do
    program = program_fixture()

    {:ok, workout_day} =
      attrs
      |> Enum.into(%{
        day_label: "Upper",
        day_number: 1,
        estimated_duration_min: 60,
        is_rest_day: false,
        muscle_groups: ["chest", "back", "shoulders"],
        program_id: program.id,
        trainer_notes: "Control the tempo.",
        week_number: 1,
        workout_type: "upper"
      })
      |> GymBro.Programs.create_workout_day()

    workout_day
  end

  def exercise_fixture(attrs \\ %{}) do
    workout_day = workout_day_fixture()

    {:ok, exercise} =
      attrs
      |> Enum.into(%{
        duration_seconds: 90,
        is_timed: false,
        name: "Incline Dumbbell Press",
        notes: "Keep your shoulder blades pinned.",
        position: 1,
        reps: "8-10",
        rest_seconds: 90,
        sets: 4,
        trainer_notes: "Stop two reps shy of failure.",
        visual_guide: "Chest up, lower with control.",
        weight_kg: 24.0,
        workout_day_id: workout_day.id
      })
      |> GymBro.Programs.create_exercise()

    exercise
  end
end
