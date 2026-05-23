defmodule GymBro.BodyStatsTest do
  use GymBro.DataCase

  alias GymBro.BodyStats

  import GymBro.BodyStatsFixtures

  describe "body weight logs" do
    test "returns the latest log for a user" do
      older = body_weight_log_fixture(%{logged_at: ~D[2026-05-08]})

      newer =
        body_weight_log_fixture(%{
          user_id: older.user_id,
          logged_at: ~D[2026-05-09],
          weight_kg: 78.9
        })

      assert BodyStats.latest_body_weight_log(older.user_id).id == newer.id
      assert [first | _] = BodyStats.list_body_weight_logs_for_user(older.user_id)
      assert first.id == newer.id
    end

    test "returns recent body weight logs in chronological order" do
      newest = body_weight_log_fixture(%{logged_at: ~D[2026-05-10]})
      oldest = body_weight_log_fixture(%{user_id: newest.user_id, logged_at: ~D[2026-05-08]})
      middle = body_weight_log_fixture(%{user_id: newest.user_id, logged_at: ~D[2026-05-09]})

      assert [first, second, third] =
               BodyStats.list_recent_body_weight_logs_for_user(newest.user_id, 3)

      assert first.id == oldest.id
      assert second.id == middle.id
      assert third.id == newest.id
    end
  end

  describe "checkins and personal records" do
    test "lists checkins and PRs for a user" do
      image = checkin_image_fixture()
      record = personal_record_fixture(%{user_id: image.user_id})

      assert [fetched_image] = BodyStats.list_checkin_images_for_user(image.user_id)
      assert fetched_image.id == image.id

      assert [fetched_record] = BodyStats.list_personal_records_for_user(image.user_id)
      assert fetched_record.id == record.id
    end

    test "filters uploaded images by type" do
      user = GymBro.AccountsFixtures.user_fixture()
      _checkin = checkin_image_fixture(%{image_type: "checkin", user_id: user.id})
      progress = checkin_image_fixture(%{image_type: "progress", user_id: user.id})

      assert [fetched] = BodyStats.list_checkin_images_for_user_by_type(user.id, "progress")
      assert fetched.id == progress.id
    end
  end
end
