defmodule GymBro.OpenAI do
  require Logger

  @default_max_retries 2
  @default_receive_timeout 90_000
  @default_connect_timeout 10_000
  @default_pool_timeout 5_000
  @default_retry_delay 1_500
  @success_preview_chars 1_500
  @transient_statuses [408, 429, 500, 502, 503, 504]
  @transient_transport_reasons [:timeout, :econnrefused, :closed]

  def send_request_to_openai(context, prompt, opts \\ []) do
    api_url = "https://api.openai.com/v1/chat/completions"
    api_key = System.get_env("OPENAI_API_KEY")
    request_id = build_request_id()
    started_at = System.monotonic_time(:millisecond)

    max_tokens = Keyword.get(opts, :max_tokens, 4000)
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    receive_timeout = Keyword.get(opts, :receive_timeout, @default_receive_timeout)

    model =
      "gpt-4o-mini"

    body = %{
      "model" => model,
      "messages" => [
        %{
          "role" => "system",
          "content" => context
        },
        %{"role" => "user", "content" => prompt}
      ],
      "temperature" => 0.5,
      "max_tokens" => max_tokens,
      "response_format" => %{"type" => "json_object"}
    }

    if !is_binary(api_key) or byte_size(api_key) == 0 do
      Logger.error("Missing OPENAI_API_KEY; cannot call OpenAI")
      {:error, :missing_openai_api_key}
    else
      log_request_start(
        request_id,
        model,
        context,
        prompt,
        max_tokens,
        receive_timeout,
        max_retries
      )

      headers = [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{api_key}"}
      ]

      req_options =
        [
          headers: headers,
          json: body,
          receive_timeout: receive_timeout,
          pool_timeout: @default_pool_timeout,
          connect_options: [timeout: @default_connect_timeout]
        ] ++ retry_options(max_retries, request_id)

      case Req.post(api_url, req_options) do
        {:ok, %{status: 200, body: response_body}} ->
          case response_body do
            %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
              log_request_success(request_id, started_at, response_body, content)
              {:ok, content}

            %{"choices" => []} ->
              log_request_failure(
                request_id,
                started_at,
                :empty_openai_response,
                max_retries
              )

              {:error, :empty_openai_response}
          end

        {:ok, %{status: status, body: body}} ->
          log_request_failure(
            request_id,
            started_at,
            {:openai_http_error, status},
            max_retries,
            "response_body=#{inspect(body, limit: 8, printable_limit: 200)}"
          )

          {:error, openai_status_error(status)}

        {:error, %Req.TransportError{reason: :timeout} = reason} ->
          log_request_failure(
            request_id,
            started_at,
            :openai_timeout,
            max_retries,
            "transport_error=#{inspect(reason)}"
          )

          {:error, :openai_timeout}

        {:error, %Req.TransportError{reason: reason}} ->
          log_request_failure(
            request_id,
            started_at,
            {:openai_transport_error, reason},
            max_retries
          )

          {:error, {:openai_transport_error, reason}}

        {:error, reason} ->
          log_request_failure(
            request_id,
            started_at,
            {:openai_request_failed, reason},
            max_retries
          )

          {:error, {:openai_request_failed, reason}}
      end
    end
  end

  defp retry_options(max_retries, request_id) when is_integer(max_retries) and max_retries > 0 do
    [
      retry: fn request, response_or_exception ->
        should_retry?(request, response_or_exception, request_id, max_retries)
      end,
      max_retries: max_retries,
      retry_delay: &retry_delay/1,
      retry_log_level: false
    ]
  end

  defp retry_options(_max_retries, _request_id), do: [retry: false]

  defp retry_delay(_retry_count), do: @default_retry_delay

  defp should_retry?(request, response_or_exception, request_id, max_retries) do
    retry_count = Req.Request.get_private(request, :req_retry_count, 0)
    should_retry = transient?(response_or_exception)

    if should_retry and retry_count < max_retries do
      Logger.warning(
        "OpenAI request retry scheduled request_id=#{request_id} failed_attempt=#{retry_count + 1} next_attempt=#{retry_count + 2} max_attempts=#{max_retries + 1} retry_delay_ms=#{retry_delay(retry_count)} reason=#{retry_reason(response_or_exception)}"
      )
    end

    should_retry
  end

  defp transient?(%Req.Response{status: status}) when status in @transient_statuses, do: true

  defp transient?(%Req.TransportError{reason: reason})
       when reason in @transient_transport_reasons,
       do: true

  defp transient?(%Req.HTTPError{protocol: :http2, reason: :unprocessed}), do: true
  defp transient?(_), do: false

  defp retry_reason(%Req.Response{status: status}), do: "http_status_#{status}"
  defp retry_reason(%Req.TransportError{reason: reason}), do: "transport_#{reason}"

  defp retry_reason(%Req.HTTPError{protocol: protocol, reason: reason}),
    do: "#{protocol}_#{reason}"

  defp retry_reason(reason), do: inspect(reason)

  defp log_request_start(
         request_id,
         model,
         context,
         prompt,
         max_tokens,
         receive_timeout,
         max_retries
       ) do
    Logger.info(
      "OpenAI request started request_id=#{request_id} model=#{model} context_chars=#{byte_size(context)} prompt_chars=#{byte_size(prompt)} max_tokens=#{max_tokens} receive_timeout_ms=#{receive_timeout} connect_timeout_ms=#{@default_connect_timeout} pool_timeout_ms=#{@default_pool_timeout} max_retries=#{max_retries}"
    )
  end

  defp log_request_success(request_id, started_at, response_body, content) do
    elapsed_ms = System.monotonic_time(:millisecond) - started_at
    usage = Map.get(response_body, "usage", %{})
    finish_reason = get_in(response_body, ["choices", Access.at(0), "finish_reason"]) || "unknown"
    {content_preview, content_truncated?} = truncate_for_log(content, @success_preview_chars)

    Logger.info(
      "OpenAI request completed request_id=#{request_id} elapsed_ms=#{elapsed_ms} finish_reason=#{finish_reason} prompt_tokens=#{Map.get(usage, "prompt_tokens", "n/a")} completion_tokens=#{Map.get(usage, "completion_tokens", "n/a")} total_tokens=#{Map.get(usage, "total_tokens", "n/a")} content_chars=#{byte_size(content)}"
    )

    Logger.info(
      "OpenAI response content request_id=#{request_id} truncated=#{content_truncated?} preview=#{inspect(content_preview, printable_limit: :infinity, limit: :infinity)}"
    )
  end

  defp log_request_failure(request_id, started_at, reason, max_retries, extra \\ nil) do
    elapsed_ms = System.monotonic_time(:millisecond) - started_at

    suffix =
      case extra do
        nil -> ""
        "" -> ""
        value -> " #{value}"
      end

    Logger.warning(
      "OpenAI request failed request_id=#{request_id} elapsed_ms=#{elapsed_ms} max_retries=#{max_retries} reason=#{format_reason(reason)}#{suffix}"
    )
  end

  defp format_reason({kind, value}), do: "#{kind}:#{inspect(value)}"
  defp format_reason(reason), do: inspect(reason)

  defp truncate_for_log(content, max_chars) when is_binary(content) and is_integer(max_chars) do
    if String.length(content) <= max_chars do
      {content, false}
    else
      {String.slice(content, 0, max_chars), true}
    end
  end

  defp build_request_id do
    System.unique_integer([:positive, :monotonic])
  end

  defp openai_status_error(408), do: :openai_timeout
  defp openai_status_error(429), do: :openai_rate_limited
  defp openai_status_error(status), do: {:openai_http_error, status}
end
