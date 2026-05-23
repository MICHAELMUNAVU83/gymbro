defmodule GymBro.TrainerFixtures do
  @moduledoc """
  Test helpers for the `GymBro.Trainer` context.
  """

  import GymBro.AccountsFixtures
  import GymBro.ProgramsFixtures

  def trainer_client_fixture(attrs \\ %{}) do
    trainer = user_fixture(%{role: "trainer"})
    client = user_fixture()

    {:ok, trainer_client} =
      attrs
      |> Enum.into(%{
        client_id: client.id,
        joined_at: ~D[2026-05-09],
        notes: "Responds well to volume blocks.",
        status: "active",
        trainer_id: trainer.id
      })
      |> GymBro.Trainer.create_trainer_client()

    trainer_client
  end

  def client_invitation_fixture(attrs \\ %{}) do
    trainer = user_fixture(%{role: "trainer"})

    {:ok, client_invitation} =
      attrs
      |> Enum.into(%{
        email: "invitee#{System.unique_integer()}@example.com",
        expires_at:
          DateTime.add(DateTime.utc_now(), 48 * 60 * 60, :second) |> DateTime.truncate(:second),
        status: "pending",
        token: Ecto.UUID.generate(),
        trainer_id: trainer.id
      })
      |> GymBro.Trainer.create_client_invitation()

    client_invitation
  end

  def trainer_exercise_override_fixture(attrs \\ %{}) do
    trainer = user_fixture(%{role: "trainer"})
    client = user_fixture()
    exercise = exercise_fixture()

    {:ok, trainer_exercise_override} =
      attrs
      |> Enum.into(%{
        active: true,
        client_id: client.id,
        exercise_id: exercise.id,
        notes: "Use a slower eccentric.",
        reps: "10-12",
        sets: 3,
        trainer_id: trainer.id,
        weight_kg: 22.5
      })
      |> GymBro.Trainer.create_trainer_exercise_override()

    trainer_exercise_override
  end
end
