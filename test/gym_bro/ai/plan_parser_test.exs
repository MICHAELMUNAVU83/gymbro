defmodule GymBro.AI.PlanParserTest do
  use ExUnit.Case, async: true

  alias GymBro.AI.PlanParser

  describe "parse/1" do
    test "parses an AI plan JSON string into normalized attrs" do
      json_plan = """
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
                        "name": "Bench Press",
                        "sets": 4,
                        "reps": "8-12",
                        "rest_seconds": 90,
                        "weight_kg": 60,
                        "notes": "Keep elbows at 45 degrees",
                        "is_timed": false,
                        "duration_seconds": null
                      },
                      {
                        "position": 2,
                        "name": "Cable Fly",
                        "sets": "3",
                        "reps": "12-15",
                        "rest_seconds": "60",
                        "weight_kg": "20.5",
                        "notes": "Slow eccentric",
                        "is_timed": "false"
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
      """

      assert {:ok, parsed_plan} = PlanParser.parse(json_plan)

      assert parsed_plan.program == %{
               name: "Lean Strength Block",
               description: "A 12-week plan for building strength while leaning out.",
               total_weeks: 4,
               current_week: 1,
               current_phase: 1,
               phase_name: "Foundation",
               status: "draft",
               source: "ai"
             }

      assert [
               %{
                 week_number: 1,
                 day_number: 1,
                 day_label: "Push",
                 workout_type: "push",
                 estimated_duration_min: 55,
                 muscle_groups: ["chest", "shoulders", "triceps"],
                 is_rest_day: false,
                 exercises: [
                   %{
                     position: 1,
                     name: "Bench Press",
                     sets: 4,
                     reps: "8-12",
                     rest_seconds: 90,
                     weight_kg: 60.0,
                     notes: "Keep elbows at 45 degrees",
                     trainer_notes: nil,
                     visual_guide: nil,
                     is_timed: false,
                     duration_seconds: nil
                   },
                   %{
                     position: 2,
                     name: "Cable Fly",
                     sets: 3,
                     reps: "12-15",
                     rest_seconds: 60,
                     weight_kg: 20.5,
                     notes: "Slow eccentric",
                     trainer_notes: nil,
                     visual_guide: nil,
                     is_timed: false,
                     duration_seconds: nil
                   }
                 ]
               },
               %{
                 week_number: 1,
                 day_number: 2,
                 day_label: "Rest",
                 workout_type: "rest",
                 estimated_duration_min: nil,
                 muscle_groups: [],
                 is_rest_day: true,
                 exercises: []
               }
               | remaining_days
             ] = parsed_plan.workout_days

      assert length(remaining_days) == 6
      assert Enum.map(parsed_plan.workout_days, & &1.week_number) == [1, 1, 2, 2, 3, 3, 4, 4]

      assert parsed_plan.raw_plan["program_name"] == "Lean Strength Block"
    end

    test "accepts a decoded map and fills in rest defaults" do
      plan = %{
        "program_name" => "Recovery Block",
        "description" => "Short recovery phase.",
        "phases" => [
          %{
            "phase" => 2,
            "name" => "Reset",
            "weeks" => [5],
            "weeks_data" => [
              %{
                "week" => 5,
                "days" => [
                  %{
                    "day" => 7,
                    "is_rest_day" => true
                  }
                ]
              }
            ]
          }
        ]
      }

      assert {:ok, parsed_plan} = PlanParser.parse(plan)

      assert parsed_plan.program.current_phase == 2
      assert parsed_plan.program.phase_name == "Reset"

      assert [%{day_label: "Rest", workout_type: "rest", is_rest_day: true}] =
               parsed_plan.workout_days
    end

    test "expands a single template week across all weeks in a phase" do
      plan = %{
        "program_name" => "Fast Block",
        "description" => "Compact generation shape.",
        "phases" => [
          %{
            "phase" => 1,
            "name" => "Foundation",
            "weeks" => [1, 2, 3],
            "weeks_data" => [
              %{
                "week" => 1,
                "days" => [
                  %{
                    "day" => 1,
                    "label" => "Upper",
                    "type" => "upper",
                    "estimated_duration_min" => 45,
                    "is_rest_day" => false,
                    "muscle_groups" => ["chest", "back"],
                    "exercises" => [
                      %{
                        "name" => "Machine Press",
                        "sets" => 3,
                        "reps" => "10-12"
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }

      assert {:ok, parsed_plan} = PlanParser.parse(plan)

      assert Enum.map(parsed_plan.workout_days, & &1.week_number) == [1, 2, 3]

      assert Enum.all?(parsed_plan.workout_days, fn day ->
               day.day_label == "Upper" and
                 day.workout_type == "upper" and
                 length(day.exercises) == 1
             end)
    end

    test "returns an error for invalid JSON" do
      assert {:error, {:invalid_json, _reason}} = PlanParser.parse("{bad json}")
    end

    test "returns an error when phases are missing" do
      assert {:error, {:missing_list, "phases"}} = PlanParser.parse(%{"program_name" => "Test"})
    end
  end
end
