defmodule GymBro.Env do
  @moduledoc false

  def load_file(path) do
    if File.exists?(path) do
      path
      |> File.stream!([], :line)
      |> Enum.each(&load_line/1)
    end

    :ok
  end

  defp load_line(line) do
    line = String.trim(line)

    if line != "" and not String.starts_with?(line, "#") do
      line
      |> String.trim_leading("export ")
      |> parse_entry()
      |> maybe_put_env()
    end
  end

  defp parse_entry(line) do
    case String.split(line, "=", parts: 2) do
      [key, value] -> {String.trim(key), normalize_value(value)}
      _ -> nil
    end
  end

  defp normalize_value(value) do
    trimmed = String.trim(value)

    if byte_size(trimmed) >= 2 and
         ((String.starts_with?(trimmed, "\"") and String.ends_with?(trimmed, "\"")) or
            (String.starts_with?(trimmed, "'") and String.ends_with?(trimmed, "'"))) do
      String.slice(trimmed, 1, byte_size(trimmed) - 2)
    else
      trimmed
    end
  end

  defp maybe_put_env({key, value}) when key != "" do
    if is_nil(System.get_env(key)) do
      System.put_env(key, value)
    end

    :ok
  end

  defp maybe_put_env(_entry), do: :ok
end