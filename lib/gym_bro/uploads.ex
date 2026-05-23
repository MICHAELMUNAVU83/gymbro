defmodule GymBro.Uploads do
  @moduledoc """
  Helpers for persisting LiveView uploads into the app's static directory.
  """

  def store!(scope, %{path: source_path}, entry) do
    extension = Path.extname(entry.client_name || "") |> normalize_extension()
    directory = destination_directory(scope)
    File.mkdir_p!(directory)

    filename =
      [
        scope_slug(scope),
        System.system_time(:millisecond),
        System.unique_integer([:positive])
      ]
      |> Enum.join("-")
      |> Kernel.<>(extension)

    destination_path = Path.join(directory, filename)
    File.cp!(source_path, destination_path)

    Path.join(["/uploads", scope_slug(scope), filename])
  end

  defp destination_directory(scope) do
    Path.join([Application.app_dir(:gym_bro, "priv/static/uploads"), scope_slug(scope)])
  end

  defp scope_slug(scope) do
    scope
    |> to_string()
    |> String.replace(~r/[^a-zA-Z0-9\/_-]+/, "-")
    |> String.replace("/", "-")
    |> String.trim("-")
    |> case do
      "" -> "general"
      value -> value
    end
  end

  defp normalize_extension(""), do: ".bin"
  defp normalize_extension(extension), do: extension
end
