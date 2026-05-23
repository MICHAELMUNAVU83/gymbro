defmodule GymBro.Seeds do
  import Ecto.Query

  alias GymBro.{Accounts, BodyStats, Programs, Profiles, Repo, Trainer, Training}
  alias GymBro.Accounts.User
  alias GymBro.BodyStats.{BodyWeightLog, CheckinImage, PersonalRecord}
  alias GymBro.Programs.{Exercise, Program, WorkoutDay}
  alias GymBro.Profiles.{TrainerProfile, UserProfile}
  alias GymBro.Trainer.{ClientInvitation, TrainerClient, TrainerExerciseOverride}
  alias GymBro.Training.{ExerciseLog, WorkoutSession}

  @demo_password "demo-pass-1234"
  @invite_email "sam.invited@gymbro.test"
  @image_urls [
    "/uploads/body-stats-1474/body-stats-1474-1778413004358-4644.jpg",
    "/uploads/body-stats-1474/body-stats-1474-1778413004351-4452.jpg",
    "/uploads/body-stats-2398/body-stats-2398-1779344311659-3301.jpg",
    "/uploads/body-stats-2398/body-stats-2398-1779344311667-1956.jpg",
    "/uploads/body-stats-2740/body-stats-2740-1779347178763-3490.jpg",
    "/uploads/body-stats-2740/body-stats-2740-1779347178770-3554.jpg"
  ]

  def run do
    today = Date.utc_today()
    week_start = Date.add(today, 1 - Date.day_of_week(today))

    reset_demo_data()

    trainer =
      create_user!(%{
        email: "coach.riley@gymbro.test",
        password: @demo_password,
        role: "trainer"
      })

    alex =
      create_user!(%{
        email: "alex.athlete@gymbro.test",
        password: @demo_password,
        role: "athlete"
      })

    maya =
      create_user!(%{
        email: "maya.client@gymbro.test",
        password: @demo_password,
        role: "athlete"
      })

    leo =
      create_user!(%{
        email: "leo.client@gymbro.test",
        password: @demo_password,
        role: "athlete"
      })

    nina =
      create_user!(%{
        email: "nina.client@gymbro.test",
        password: @demo_password,
        role: "athlete"
      })

    create_trainer_profile!(trainer.id, %{
      bio:
        "Strength-first online coach focused on sustainable fat loss, clean technique, and simple habits athletes can actually keep.",
      specialization: "strength",
      years_experience: 8,
      certification: "NSCA-CPT",
      max_clients: 25
    })

    create_user_profile!(alex.id, %{
      age: 29,
      height_cm: 178.0,
      weight_kg: 84.2,
      goal_weight_kg: 79.0,
      fitness_level: "intermediate",
      goal: "weight_loss",
      days_per_week: 4,
      equipment: "gym",
      onboarding_complete: true
    })

    create_user_profile!(maya.id, %{
      age: 27,
      height_cm: 167.0,
      weight_kg: 75.4,
      goal_weight_kg: 69.0,
      fitness_level: "intermediate",
      goal: "weight_loss",
      days_per_week: 4,
      equipment: "gym",
      onboarding_complete: true
    })

    create_user_profile!(leo.id, %{
      age: 34,
      height_cm: 183.0,
      weight_kg: 96.5,
      goal_weight_kg: 88.0,
      fitness_level: "advanced",
      goal: "weight_loss",
      days_per_week: 5,
      equipment: "gym",
      onboarding_complete: true
    })

    create_user_profile!(nina.id, %{
      age: 31,
      height_cm: 171.0,
      weight_kg: 68.4,
      goal_weight_kg: 64.0,
      fitness_level: "beginner",
      goal: "weight_loss",
      days_per_week: 3,
      equipment: "gym",
      onboarding_complete: true
    })

    create_trainer_client!(trainer.id, maya.id, %{
      status: "active",
      notes: "Responds well to short, focused cues. Keep sessions efficient and confidence high.",
      joined_at: Date.add(today, -45)
    })

    create_trainer_client!(trainer.id, leo.id, %{
      status: "active",
      notes:
        "Excellent work capacity. Push progression on compound lifts and reinforce recovery.",
      joined_at: Date.add(today, -60)
    })

    create_trainer_client!(trainer.id, nina.id, %{
      status: "active",
      notes: "Needs accountability around consistency and weekly check-ins.",
      joined_at: Date.add(today, -22)
    })

    alex_program =
      create_program_with_structure!(
        alex,
        alex,
        %{
          name: "Summer Cut Builder",
          description:
            "A practical four-day cut phase with enough structure to explore every athlete screen.",
          total_weeks: 12,
          current_week: 2,
          current_phase: 1,
          phase_name: "Foundation",
          status: "active",
          source: "ai",
          ai_raw_plan: %{"seeded" => true, "focus" => "cut", "owner" => "alex"}
        },
        repeat_days(fat_loss_days(), 2)
      )

    maya_program =
      create_program_with_structure!(
        maya,
        trainer,
        %{
          name: "Coach Riley Momentum Block",
          description:
            "Trainer-led fat loss block with a live session in progress for dashboard testing.",
          total_weeks: 12,
          current_week: 1,
          current_phase: 1,
          phase_name: "Foundation",
          status: "active",
          source: "trainer",
          ai_raw_plan: %{"seeded" => true, "focus" => "coached_cut", "owner" => "maya"}
        },
        repeat_days(momentum_days(), 2)
      )

    leo_program =
      create_program_with_structure!(
        leo,
        trainer,
        %{
          name: "Coach Riley Performance Cut",
          description: "Higher-frequency client block with recent wins, PRs, and progress data.",
          total_weeks: 12,
          current_week: 2,
          current_phase: 2,
          phase_name: "Progression",
          status: "active",
          source: "ai_trainer_edited",
          ai_raw_plan: %{"seeded" => true, "focus" => "performance_cut", "owner" => "leo"}
        },
        repeat_days(performance_days(), 2)
      )

    _nina_program =
      create_program_with_structure!(
        nina,
        trainer,
        %{
          name: "Consistency Restart",
          description: "Simple three-day entry block designed for a client who needs momentum.",
          total_weeks: 12,
          current_week: 1,
          current_phase: 1,
          phase_name: "Foundation",
          status: "active",
          source: "trainer",
          ai_raw_plan: %{"seeded" => true, "focus" => "restart", "owner" => "nina"}
        },
        repeat_days(reset_days(), 2)
      )

    seed_weight_logs(alex.id, [
      {Date.add(today, -21), 84.2, "Starting point before the cut."},
      {Date.add(today, -18), 83.7, "Good adherence this week."},
      {Date.add(today, -15), 83.4, "Slight drop after tightening nutrition."},
      {Date.add(today, -12), 82.9, "Training energy still high."},
      {Date.add(today, -9), 82.6, "Kept weekend meals in range."},
      {Date.add(today, -6), 82.1, "Morning weigh-in after a rest day."},
      {Date.add(today, -3), 81.8, "Cardio added after lifts."},
      {today, 81.6, "Current check-in."}
    ])

    seed_weight_logs(maya.id, [
      {Date.add(today, -18), 75.4, "Starting weight."},
      {Date.add(today, -14), 74.9, "Sleep improved this week."},
      {Date.add(today, -10), 74.4, "Moving well."},
      {Date.add(today, -7), 74.0, "Weekend stayed on plan."},
      {Date.add(today, -4), 73.5, "Waist is trending down."},
      {today, 72.9, "Weekly check-in before today's workout."}
    ])

    seed_weight_logs(leo.id, [
      {Date.add(today, -24), 96.5, "Initial logged weight."},
      {Date.add(today, -20), 95.8, "Water came down quickly."},
      {Date.add(today, -16), 95.0, "Still pushing strength."},
      {Date.add(today, -12), 94.3, "Great adherence."},
      {Date.add(today, -8), 93.9, "Travel week handled well."},
      {Date.add(today, -5), 93.3, "Recovery improved."},
      {Date.add(today, -2), 92.9, "Leanest look so far."},
      {today, 92.8, "Fast morning weigh-in."}
    ])

    seed_weight_logs(nina.id, [
      {Date.add(today, -16), 68.4, "Onboarding baseline."},
      {Date.add(today, -11), 68.0, "First good week."},
      {Date.add(today, -6), 67.8, "Missed a couple sessions."}
    ])

    seed_images(alex.id, [
      {"checkin", @image_urls |> Enum.at(0), Date.add(today, -14), "Front relaxed after week 1."},
      {"progress", @image_urls |> Enum.at(1), Date.add(today, -7), "Week 2 comparison shot."},
      {"checkin", @image_urls |> Enum.at(2), today, "Current weekly check-in."}
    ])

    seed_images(maya.id, [
      {"progress", @image_urls |> Enum.at(3), Date.add(today, -7), "Posing and posture update."},
      {"checkin", @image_urls |> Enum.at(4), today, "Weekly check-in before training."}
    ])

    seed_images(leo.id, [
      {"checkin", @image_urls |> Enum.at(5), Date.add(today, -5), "Mid-block progress."},
      {"progress", @image_urls |> Enum.at(2), Date.add(today, -2), "Current conditioning look."}
    ])

    seed_personal_records(alex.id, [
      {"Bench Press", 92.5, 5, Date.add(today, -9)},
      {"Romanian Deadlift", 120.0, 6, Date.add(today, -4)}
    ])

    seed_personal_records(maya.id, [
      {"Dumbbell Romanian Deadlift", 28.0, 10, Date.add(today, -6)}
    ])

    seed_personal_records(leo.id, [
      {"Back Squat", 160.0, 3, Date.add(today, -10)},
      {"Weighted Pull-Up", 22.5, 6, Date.add(today, -3)}
    ])

    alex_week_2_day_1 = find_day!(alex_program, 2, 1)
    alex_week_2_day_2 = find_day!(alex_program, 2, 2)

    create_completed_session!(
      alex.id,
      alex_week_2_day_1,
      dt(Date.add(week_start, 0), 6, 45),
      3_120,
      "Moved well and kept the pace up.",
      nil,
      %{
        "Incline Dumbbell Press" => [
          %{set_number: 1, reps_completed: 10, weight_kg: 26.0, rpe: 7},
          %{set_number: 2, reps_completed: 9, weight_kg: 26.0, rpe: 8}
        ],
        "Chest Supported Row" => [
          %{set_number: 1, reps_completed: 12, weight_kg: 32.0, rpe: 8}
        ]
      }
    )

    create_completed_session!(
      alex.id,
      alex_week_2_day_2,
      dt(Date.add(week_start, 2), 18, 10),
      2_940,
      "Leg day felt solid.",
      nil,
      %{
        "Hack Squat" => [
          %{set_number: 1, reps_completed: 10, weight_kg: 70.0, rpe: 8},
          %{set_number: 2, reps_completed: 9, weight_kg: 75.0, rpe: 9}
        ]
      }
    )

    maya_week_1_day_1 = find_day!(maya_program, 1, 1)
    maya_week_1_day_2 = find_day!(maya_program, 1, 2)

    create_completed_session!(
      maya.id,
      maya_week_1_day_1,
      dt(Date.add(today, -2), 7, 0),
      2_700,
      "Strong effort and steady pace.",
      "Keep the same control on the next upper session.",
      %{
        "Goblet Squat" => [
          %{set_number: 1, reps_completed: 12, weight_kg: 24.0, rpe: 7},
          %{set_number: 2, reps_completed: 12, weight_kg: 24.0, rpe: 8}
        ]
      }
    )

    create_active_session!(
      maya.id,
      maya_week_1_day_2,
      dt(today, 6, 20),
      %{
        "Bench Press" => [
          %{set_number: 1, reps_completed: 6, weight_kg: 42.5, rpe: 8},
          %{set_number: 2, reps_completed: 6, weight_kg: 42.5, rpe: 8}
        ],
        "Lat Pulldown" => [
          %{set_number: 1, reps_completed: 10, weight_kg: 35.0, rpe: 7}
        ]
      }
    )

    leo_week_2_day_1 = find_day!(leo_program, 2, 1)
    leo_week_2_day_2 = find_day!(leo_program, 2, 2)
    leo_week_2_day_3 = find_day!(leo_program, 2, 3)

    create_completed_session!(
      leo.id,
      leo_week_2_day_1,
      dt(Date.add(week_start, 0), 5, 50),
      3_300,
      "Top set moved fast.",
      "Add 2.5 kg next week if bar speed holds.",
      %{
        "Back Squat" => [
          %{set_number: 1, reps_completed: 5, weight_kg: 140.0, rpe: 8},
          %{set_number: 2, reps_completed: 5, weight_kg: 145.0, rpe: 9}
        ]
      }
    )

    create_completed_session!(
      leo.id,
      leo_week_2_day_2,
      dt(Date.add(week_start, 1), 6, 10),
      3_060,
      "Upper session stayed crisp.",
      "Good control on bench tempo.",
      %{
        "Bench Press" => [
          %{set_number: 1, reps_completed: 6, weight_kg: 100.0, rpe: 8},
          %{set_number: 2, reps_completed: 6, weight_kg: 102.5, rpe: 9}
        ]
      }
    )

    create_completed_session!(
      leo.id,
      leo_week_2_day_3,
      dt(today, 5, 40),
      2_880,
      "Conditioning day completed before work.",
      "Recovery looked much better today.",
      %{
        "Assault Bike" => [
          %{set_number: 1, duration_seconds: 45, rpe: 8},
          %{set_number: 2, duration_seconds: 45, rpe: 9}
        ]
      }
    )

    leo_override_day = find_day!(leo_program, 2, 2)
    leo_override_exercise = find_exercise!(leo_override_day, "Bench Press")

    create_trainer_exercise_override!(%{
      trainer_id: trainer.id,
      client_id: leo.id,
      exercise_id: leo_override_exercise.id,
      sets: 4,
      reps: "6-8",
      weight_kg: 105.0,
      notes: "Coach override: push the top set, then keep back-off sets honest.",
      active: true
    })

    invitation = create_invitation!(trainer.id, @invite_email)

    IO.puts("""

    Seeded GymBro demo data.

    Login password for every seeded account: #{@demo_password}

    Trainer:
      coach.riley@gymbro.test

    Athlete:
      alex.athlete@gymbro.test

    Trainer clients:
      maya.client@gymbro.test  (has a live session right now)
      leo.client@gymbro.test   (has recent wins and an exercise override)
      nina.client@gymbro.test  (shows follow-up alerts)

    Pending invitation:
      #{@invite_email}
      http://localhost:4000/join/#{invitation.token}
    """)
  end

  defp reset_demo_data do
    emails = demo_emails()

    users = Repo.all(from user in User, where: user.email in ^emails)
    user_ids = Enum.map(users, & &1.id)

    program_ids =
      Repo.all(from program in Program, where: program.user_id in ^user_ids, select: program.id)

    workout_day_ids =
      Repo.all(
        from workout_day in WorkoutDay,
          where: workout_day.program_id in ^program_ids,
          select: workout_day.id
      )

    exercise_ids =
      Repo.all(
        from exercise in Exercise,
          where: exercise.workout_day_id in ^workout_day_ids,
          select: exercise.id
      )

    session_ids =
      Repo.all(
        from workout_session in WorkoutSession,
          where: workout_session.user_id in ^user_ids,
          select: workout_session.id
      )

    Repo.delete_all(
      from override in TrainerExerciseOverride,
        where:
          override.exercise_id in ^exercise_ids or override.client_id in ^user_ids or
            override.trainer_id in ^user_ids
    )

    Repo.delete_all(
      from log in ExerciseLog,
        where: log.workout_session_id in ^session_ids
    )

    Repo.delete_all(
      from workout_session in WorkoutSession, where: workout_session.id in ^session_ids
    )

    Repo.delete_all(from exercise in Exercise, where: exercise.id in ^exercise_ids)
    Repo.delete_all(from workout_day in WorkoutDay, where: workout_day.id in ^workout_day_ids)
    Repo.delete_all(from program in Program, where: program.id in ^program_ids)

    Repo.delete_all(
      from invitation in ClientInvitation,
        where: invitation.trainer_id in ^user_ids or invitation.email == ^@invite_email
    )

    Repo.delete_all(
      from relationship in TrainerClient,
        where: relationship.trainer_id in ^user_ids or relationship.client_id in ^user_ids
    )

    Repo.delete_all(from record in PersonalRecord, where: record.user_id in ^user_ids)
    Repo.delete_all(from image in CheckinImage, where: image.user_id in ^user_ids)
    Repo.delete_all(from weight_log in BodyWeightLog, where: weight_log.user_id in ^user_ids)
    Repo.delete_all(from profile in TrainerProfile, where: profile.user_id in ^user_ids)
    Repo.delete_all(from profile in UserProfile, where: profile.user_id in ^user_ids)
    Repo.delete_all(from user in User, where: user.id in ^user_ids)
  end

  defp demo_emails do
    [
      "coach.riley@gymbro.test",
      "alex.athlete@gymbro.test",
      "maya.client@gymbro.test",
      "leo.client@gymbro.test",
      "nina.client@gymbro.test"
    ]
  end

  defp create_user!(attrs) do
    {:ok, user} = Accounts.register_user(attrs)
    user |> User.confirm_changeset() |> Repo.update!()
  end

  defp create_trainer_profile!(user_id, attrs) do
    {:ok, profile} = Profiles.create_trainer_profile(Map.put(attrs, :user_id, user_id))
    profile
  end

  defp create_user_profile!(user_id, attrs) do
    {:ok, profile} = Profiles.create_user_profile(Map.put(attrs, :user_id, user_id))
    profile
  end

  defp create_trainer_client!(trainer_id, client_id, attrs) do
    attrs =
      attrs
      |> Map.put(:trainer_id, trainer_id)
      |> Map.put(:client_id, client_id)

    {:ok, relationship} = Trainer.create_trainer_client(attrs)
    relationship
  end

  defp create_program_with_structure!(user, creator, attrs, workout_days) do
    {:ok, program} =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put(:created_by_id, creator.id)
      |> Programs.create_program()

    Enum.each(workout_days, fn workout_day_attrs ->
      {:ok, workout_day} =
        workout_day_attrs
        |> Map.drop([:exercises])
        |> Map.put(:program_id, program.id)
        |> Programs.create_workout_day()

      workout_day_attrs
      |> Map.fetch!(:exercises)
      |> Enum.with_index(1)
      |> Enum.each(fn {exercise_attrs, index} ->
        {:ok, _exercise} =
          exercise_attrs
          |> Map.put_new(:position, index)
          |> Map.put(:workout_day_id, workout_day.id)
          |> Programs.create_exercise()
      end)
    end)

    Programs.preload_program_structure(program)
  end

  defp seed_weight_logs(user_id, entries) do
    Enum.each(entries, fn {logged_at, weight_kg, notes} ->
      {:ok, _log} =
        BodyStats.create_body_weight_log(%{
          user_id: user_id,
          logged_at: logged_at,
          weight_kg: weight_kg,
          notes: notes
        })
    end)
  end

  defp seed_images(user_id, entries) do
    Enum.each(entries, fn {image_type, image_url, logged_at, notes} ->
      {:ok, _image} =
        BodyStats.create_checkin_image(%{
          user_id: user_id,
          image_type: image_type,
          image_url: image_url,
          logged_at: logged_at,
          notes: notes,
          visible_to_trainer: true
        })
    end)
  end

  defp seed_personal_records(user_id, entries) do
    Enum.each(entries, fn {exercise_name, weight_kg, reps, achieved_at} ->
      {:ok, _record} =
        BodyStats.create_personal_record(%{
          user_id: user_id,
          exercise_name: exercise_name,
          weight_kg: weight_kg,
          reps: reps,
          achieved_at: achieved_at
        })
    end)
  end

  defp create_completed_session!(
         user_id,
         workout_day,
         started_at,
         duration_seconds,
         notes,
         trainer_feedback,
         logs_by_exercise
       ) do
    completed_at = DateTime.add(started_at, duration_seconds, :second)

    {:ok, session} =
      Training.create_workout_session(%{
        user_id: user_id,
        workout_day_id: workout_day.id,
        started_at: started_at,
        completed_at: completed_at,
        duration_seconds: duration_seconds,
        status: "completed",
        notes: notes,
        trainer_feedback: trainer_feedback
      })

    create_logs!(session, workout_day, logs_by_exercise)
    session
  end

  defp create_active_session!(user_id, workout_day, started_at, logs_by_exercise) do
    {:ok, session} =
      Training.create_workout_session(%{
        user_id: user_id,
        workout_day_id: workout_day.id,
        started_at: started_at,
        status: "active",
        notes: "Live workout in progress."
      })

    create_logs!(session, workout_day, logs_by_exercise)
    session
  end

  defp create_logs!(session, workout_day, logs_by_exercise) do
    exercises_by_name = Map.new(workout_day.exercises, &{&1.name, &1})

    Enum.each(logs_by_exercise, fn {exercise_name, set_logs} ->
      exercise = Map.fetch!(exercises_by_name, exercise_name)

      Enum.each(set_logs, fn set_log ->
        attrs =
          set_log
          |> Map.put(:workout_session_id, session.id)
          |> Map.put(:exercise_id, exercise.id)

        {:ok, _log} = Training.create_exercise_log(attrs)
      end)
    end)
  end

  defp create_trainer_exercise_override!(attrs) do
    {:ok, override} = Trainer.create_trainer_exercise_override(attrs)
    override
  end

  defp create_invitation!(trainer_id, email) do
    {:ok, invitation} = Trainer.issue_client_invitation(trainer_id, email)
    invitation
  end

  defp find_day!(program, week_number, day_number) do
    Enum.find(program.workout_days, fn workout_day ->
      workout_day.week_number == week_number and workout_day.day_number == day_number
    end) || raise("Missing seeded workout day for week #{week_number}, day #{day_number}")
  end

  defp find_exercise!(workout_day, name) do
    Enum.find(workout_day.exercises, &(&1.name == name)) ||
      raise("Missing seeded exercise #{inspect(name)}")
  end

  defp dt(date, hour, minute) do
    DateTime.new!(date, Time.new!(hour, minute, 0), "Etc/UTC")
  end

  defp repeat_days(base_days, weeks) do
    Enum.flat_map(1..weeks, fn week_number ->
      Enum.map(base_days, fn workout_day ->
        notes =
          case {week_number, Map.get(workout_day, :trainer_notes)} do
            {1, note} -> note
            {_, nil} -> "Week #{week_number}: progress the load if bar speed stays clean."
            {_, note} -> "Week #{week_number}: #{note}"
          end

        workout_day
        |> Map.put(:week_number, week_number)
        |> Map.put(:trainer_notes, notes)
      end)
    end)
  end

  defp fat_loss_days do
    [
      %{
        day_number: 1,
        day_label: "Upper Builder",
        workout_type: "upper",
        estimated_duration_min: 58,
        muscle_groups: ["chest", "back", "shoulders"],
        trainer_notes: "Stay one rep shy of failure on the final set.",
        exercises: [
          exercise("Incline Dumbbell Press", 4, "8-10", 75, 26.0,
            notes: "Drive feet down and keep rib cage stacked."
          ),
          exercise("Chest Supported Row", 4, "10-12", 75, 32.0,
            notes: "Pause at the top for one count."
          ),
          exercise("Cable Lateral Raise", 3, "12-15", 45, 7.5,
            notes: "Smooth tempo, no swinging."
          ),
          exercise("Rope Pushdown", 3, "12-15", 45, 20.0, notes: "Lock the elbows in place.")
        ]
      },
      %{
        day_number: 2,
        day_label: "Lower Builder",
        workout_type: "lower",
        estimated_duration_min: 60,
        muscle_groups: ["quads", "glutes", "hamstrings"],
        trainer_notes: "Own the lowering phase on every squat pattern.",
        exercises: [
          exercise("Hack Squat", 4, "8-10", 90, 70.0,
            notes: "Control depth and keep heels heavy."
          ),
          exercise("Romanian Deadlift", 4, "8-10", 90, 85.0,
            notes: "Keep the lats tight and chase hamstring tension."
          ),
          exercise("Walking Lunge", 3, "10/side", 60, 16.0,
            notes: "Long stride and upright torso."
          ),
          exercise("Seated Leg Curl", 3, "12-15", 45, 35.0,
            notes: "Squeeze hard at full flexion."
          )
        ]
      },
      %{
        day_number: 3,
        day_label: "Push-Pull Density",
        workout_type: "upper",
        estimated_duration_min: 52,
        muscle_groups: ["chest", "back", "arms"],
        trainer_notes: "Move briskly but keep every rep clean.",
        exercises: [
          exercise("Flat Dumbbell Press", 3, "10-12", 60, 24.0,
            notes: "Touch lightly and drive up together."
          ),
          exercise("Single Arm Cable Row", 3, "10-12", 60, 22.5,
            notes: "Reach long at the front."
          ),
          exercise("EZ Bar Curl", 3, "10-12", 45, 25.0, notes: "Do not rock through the hips."),
          exercise("Bike Sprint", 6, "AMRAP", 45, nil,
            notes: "Hard effort, full recovery between rounds.",
            is_timed: true,
            duration_seconds: 20
          )
        ]
      },
      %{
        day_number: 4,
        day_label: "Conditioning Finish",
        workout_type: "lower",
        estimated_duration_min: 35,
        muscle_groups: ["core", "conditioning"],
        trainer_notes: "Treat this like recovery plus calorie burn.",
        exercises: [
          exercise("Sled Push", 6, "20m", 60, 60.0, notes: "Fast feet and tall posture."),
          exercise("Kettlebell Swing", 4, "15", 45, 20.0,
            notes: "Snap the hips, do not squat it."
          ),
          exercise("Dead Bug", 3, "10/side", 30, nil,
            notes: "Flatten the low back into the floor."
          )
        ]
      }
    ]
  end

  defp momentum_days do
    [
      %{
        day_number: 1,
        day_label: "Lower Momentum",
        workout_type: "lower",
        estimated_duration_min: 50,
        muscle_groups: ["quads", "glutes", "core"],
        trainer_notes:
          "Keep confidence high and leave the gym feeling better than you walked in.",
        exercises: [
          exercise("Goblet Squat", 4, "10-12", 60, 24.0, notes: "Brace before every rep."),
          exercise("Dumbbell Romanian Deadlift", 4, "10", 75, 28.0,
            notes: "Long hamstrings, soft knees."
          ),
          exercise("Step-Up", 3, "10/side", 60, 14.0, notes: "Drive through the front leg."),
          exercise("Plank", 3, "AMRAP", 30, nil,
            notes: "Exhale hard and keep ribs down.",
            is_timed: true,
            duration_seconds: 40
          )
        ]
      },
      %{
        day_number: 2,
        day_label: "Upper Momentum",
        workout_type: "upper",
        estimated_duration_min: 56,
        muscle_groups: ["chest", "back", "shoulders"],
        trainer_notes: "Smooth tempo, clean setup, and full range every set.",
        exercises: [
          exercise("Bench Press", 4, "6-8", 90, 42.5, notes: "Stack wrists over elbows."),
          exercise("Lat Pulldown", 4, "8-10", 75, 35.0,
            notes: "Pull elbows into the back pockets."
          ),
          exercise("Seated Dumbbell Shoulder Press", 3, "10", 60, 14.0,
            notes: "Keep the rib cage quiet."
          ),
          exercise("Cable Triceps Extension", 3, "12-15", 45, 15.0,
            notes: "Split stance and full lockout."
          )
        ]
      },
      %{
        day_number: 3,
        day_label: "Circuit Day",
        workout_type: "upper",
        estimated_duration_min: 38,
        muscle_groups: ["conditioning", "core"],
        trainer_notes: "Stay moving and keep transitions short.",
        exercises: [
          exercise("Bike Sprint", 5, "AMRAP", 45, nil,
            notes: "Strong effort, full recovery rhythm.",
            is_timed: true,
            duration_seconds: 30
          ),
          exercise("Kettlebell Deadlift", 4, "12", 45, 24.0, notes: "Push the floor away."),
          exercise("Farmer Carry", 4, "30m", 45, 18.0, notes: "Tall posture and steady steps.")
        ]
      },
      %{
        day_number: 4,
        day_label: "Recovery Walk",
        workout_type: "rest",
        estimated_duration_min: 30,
        muscle_groups: ["recovery"],
        is_rest_day: true,
        trainer_notes: "Easy walk, mobility, and hydration.",
        exercises: []
      }
    ]
  end

  defp performance_days do
    [
      %{
        day_number: 1,
        day_label: "Lower Strength",
        workout_type: "lower",
        estimated_duration_min: 64,
        muscle_groups: ["quads", "glutes", "hamstrings"],
        trainer_notes: "Earn the top set, then keep every back-off rep identical.",
        exercises: [
          exercise("Back Squat", 4, "4-6", 120, 145.0, notes: "Big breath, stay over mid-foot."),
          exercise("Romanian Deadlift", 4, "6-8", 105, 110.0,
            notes: "Keep tension on the hamstrings."
          ),
          exercise("Leg Press", 3, "10-12", 75, 180.0, notes: "Control the bottom range."),
          exercise("Ab Wheel", 3, "10", 45, nil, notes: "Only roll as far as you can brace.")
        ]
      },
      %{
        day_number: 2,
        day_label: "Upper Strength",
        workout_type: "upper",
        estimated_duration_min: 62,
        muscle_groups: ["chest", "back", "shoulders"],
        trainer_notes: "Push output on the main press, then own the accessories.",
        exercises: [
          exercise("Bench Press", 4, "5-6", 120, 100.0, notes: "Pause softly on the chest."),
          exercise("Weighted Pull-Up", 4, "5-6", 90, 20.0,
            notes: "Start every rep from a dead hang."
          ),
          exercise("Chest Supported Row", 3, "8-10", 75, 38.0,
            notes: "Pull low and keep the chest pinned."
          ),
          exercise("Cable Lateral Raise", 3, "12-15", 45, 8.0, notes: "Smooth, controlled arcs.")
        ]
      },
      %{
        day_number: 3,
        day_label: "Conditioning Flush",
        workout_type: "upper",
        estimated_duration_min: 34,
        muscle_groups: ["conditioning", "core"],
        trainer_notes: "Keep this sharp, not exhausting.",
        exercises: [
          exercise("Assault Bike", 6, "AMRAP", 60, nil,
            notes: "Work hard for the whole interval.",
            is_timed: true,
            duration_seconds: 45
          ),
          exercise("Walking Lunge", 3, "12/side", 45, 18.0,
            notes: "Long stride and controlled steps."
          ),
          exercise("Hanging Knee Raise", 3, "12", 30, nil, notes: "Curl pelvis under at the top.")
        ]
      },
      %{
        day_number: 4,
        day_label: "Pump Day",
        workout_type: "upper",
        estimated_duration_min: 48,
        muscle_groups: ["arms", "shoulders", "back"],
        trainer_notes: "Chase quality contractions and keep rest honest.",
        exercises: [
          exercise("Machine Chest Press", 3, "10-12", 60, 60.0,
            notes: "Pause briefly in the stretched position."
          ),
          exercise("Single Arm Row", 3, "10-12", 60, 34.0, notes: "Drive elbow toward the hip."),
          exercise("Cable Curl", 3, "12-15", 45, 17.5, notes: "Stay fixed at the shoulder."),
          exercise("Overhead Rope Extension", 3, "12-15", 45, 17.5,
            notes: "Stretch hard behind the head."
          )
        ]
      }
    ]
  end

  defp reset_days do
    [
      %{
        day_number: 1,
        day_label: "Full Body A",
        workout_type: "upper",
        estimated_duration_min: 42,
        muscle_groups: ["full_body"],
        trainer_notes: "Keep every set simple, calm, and repeatable.",
        exercises: [
          exercise("Leg Press", 3, "10", 75, 70.0, notes: "Stay smooth through the full range."),
          exercise("Machine Chest Press", 3, "10", 60, 35.0, notes: "Controlled lowering phase."),
          exercise("Seated Row", 3, "10", 60, 30.0,
            notes: "Finish with elbows close to the ribs."
          )
        ]
      },
      %{
        day_number: 2,
        day_label: "Full Body B",
        workout_type: "lower",
        estimated_duration_min: 40,
        muscle_groups: ["full_body"],
        trainer_notes: "Build confidence through clean, comfortable reps.",
        exercises: [
          exercise("Goblet Squat", 3, "10", 60, 16.0, notes: "Brace and keep the chest tall."),
          exercise("Lat Pulldown", 3, "10", 60, 25.0, notes: "Pull to the top of the chest."),
          exercise("Hip Bridge", 3, "12", 45, nil, notes: "Pause at full lockout.")
        ]
      },
      %{
        day_number: 3,
        day_label: "Walk + Mobility",
        workout_type: "rest",
        estimated_duration_min: 30,
        muscle_groups: ["recovery"],
        is_rest_day: true,
        trainer_notes: "A win here is simply showing up and moving.",
        exercises: []
      }
    ]
  end

  defp exercise(name, sets, reps, rest_seconds, weight_kg, extra) do
    extra
    |> Enum.into(%{
      name: name,
      sets: sets,
      reps: reps,
      rest_seconds: rest_seconds,
      weight_kg: weight_kg
    })
  end
end

GymBro.Seeds.run()
