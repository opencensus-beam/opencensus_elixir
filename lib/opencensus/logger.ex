defmodule Opencensus.Logger do
  @moduledoc """
  Updates Elixir's Logger metadata to match Erlang's logger metadata.

  `set_logger_metadata/0` and `set_logger_metadata/1` update the following attributes in
  `Logger.metadata/0`:

  * `trace_id`
  * `span_id`
  * `trace_options`

  You won't need to use this module if you use the macros in `Opencensus.Trace`.

  If you use `Logging`, or users of your framework might plausibly use `Logging`, you [SHOULD]
  call `set_logger_metadata/0` after using functions in [`:ocp`] to manipulate the span context
  stored in the process dictionary.

  [:ocp]: https://hexdocs.pm/opencensus/ocp.html

  We'll be able to deprecate these functions when Elixir unifies `:logger` and `Logger` metadata
  in 1.10 or whichever release [first requires Erlang 21 or better][6611]. To check whether that
  has already happened, try this at the `iex` prompt:

  ```elixir
  :ocp.with_child_span("traced")
  :logger.get_process_metadata()
  Logger.metadata(()
  ```

  If the metadata output from the second and third lines match, we can start deprecating.

  [6611]: https://github.com/elixir-lang/elixir/issues/6611
  [MAY]: https://tools.ietf.org/html/rfc2119#section-5
  [SHOULD]: https://tools.ietf.org/html/rfc2119#section-3
  """

  alias Opencensus.SpanContext

  @doc "Sets the Logger metadata according to the current span context."
  def set_logger_metadata, do: set_logger_metadata(:ocp.current_span_ctx())

  @doc "Sets the Logger metadata according to a supplied span context."
  @spec set_logger_metadata(:opencensus.span_ctx() | :undefined) :: :ok
  def set_logger_metadata(span_ctx)

  def set_logger_metadata(:undefined), do: set_logger_metadata(nil, nil, nil)

  def set_logger_metadata(span_ctx) do
    context = SpanContext.from(span_ctx)

    set_logger_metadata(
      SpanContext.hex_trace_id(context.trace_id),
      SpanContext.hex_span_id(context.span_id),
      context.trace_options
    )
  end

  defp set_logger_metadata(trace_id, span_id, trace_options) do
    Logger.metadata(trace_id: trace_id, span_id: span_id, trace_options: trace_options)
    :ok
  end
end
