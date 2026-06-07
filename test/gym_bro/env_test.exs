defmodule GymBro.EnvTest do
  use ExUnit.Case, async: false

  alias GymBro.Env

  test "load_file/1 loads dotenv values without overriding existing env" do
    suffix = System.unique_integer([:positive])

    plain_key = "GYMBRO_ENV_TEST_PLAIN_#{suffix}"
    quoted_key = "GYMBRO_ENV_TEST_QUOTED_#{suffix}"
    single_key = "GYMBRO_ENV_TEST_SINGLE_#{suffix}"
    exported_key = "GYMBRO_ENV_TEST_EXPORTED_#{suffix}"
    existing_key = "GYMBRO_ENV_TEST_EXISTING_#{suffix}"

    restore_env([plain_key, quoted_key, single_key, exported_key, existing_key])

    System.put_env(existing_key, "already-set")

    env_file =
      write_env_file("""
      # comment
      #{plain_key}=plain-value
      #{quoted_key}="quoted value"
      #{single_key}='single value'
      export #{exported_key}=exported-value
      invalid line
      #{existing_key}=from-file
      """)

    assert :ok = Env.load_file(env_file)

    assert System.get_env(plain_key) == "plain-value"
    assert System.get_env(quoted_key) == "quoted value"
    assert System.get_env(single_key) == "single value"
    assert System.get_env(exported_key) == "exported-value"
    assert System.get_env(existing_key) == "already-set"
  end

  test "load_file/1 ignores missing files" do
    missing_path =
      Path.join(System.tmp_dir!(), "gym_bro_missing_#{System.unique_integer([:positive])}.env")

    assert :ok = Env.load_file(missing_path)
  end

  defp restore_env(keys) do
    previous_values = Map.new(keys, &{&1, System.get_env(&1)})

    Enum.each(keys, &System.delete_env/1)

    on_exit(fn ->
      Enum.each(previous_values, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)
  end

  defp write_env_file(contents) do
    path = Path.join(System.tmp_dir!(), "gym_bro_env_#{System.unique_integer([:positive])}.env")
    File.write!(path, contents)

    on_exit(fn ->
      File.rm(path)
    end)

    path
  end
end
