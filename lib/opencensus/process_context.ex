defmodule Opencensus.ProcessContext do
  @moduledoc """
  Experimental behaviour to control how the span context is tracked.

  Use the matching methods in `Opencensus.ProcessContext.ConfiguredImplementation`.
  """

  @doc """
  Put the current context.

  Returns the previous value.
  """
  @callback put_span_ctx(span_ctx :: :opencensus.span_ctx() | :undefined) ::
              :opencensus.span_ctx() | :undefined

  @doc """
  Get the current span context.

  Implementations [SHOULD NOT] attempt recovery if the span context isn't where `c:put_span_ctx/1`
  should have put it. Callers [MAY] rely on this behaviour, using `c:put_span_ctx/1` to "put back"
  any value they got from `c:get_span_ctx/0`.

  [SHOULD NOT]: https://tools.ietf.org/html/rfc2119#section-4
  [MAY]: https://tools.ietf.org/html/rfc2119#section-5
  """
  @callback get_span_ctx() :: :opencensus.span_ctx() | :undefined

  @doc """
  Recover the current span context by less reliable means.

  Implementations [SHOULD] check `c:get_span_ctx/0` and return its value if not `:undefined`.

  Callers [SHOULD] check `c:get_span_ctx/0` and avoid calling `c:recover_span_ctx/0` if possible.
  Callers [MUST NOT] pass a value obtained via `c:recover_span_ctx/0` to `c:put_span_ctx/1`.

  [SHOULD]: https://tools.ietf.org/html/rfc2119#section-3
  [MUST NOT]: https://tools.ietf.org/html/rfc2119#section-2
  """
  @callback recover_span_ctx() :: :opencensus.span_ctx() | :undefined
end

defmodule Opencensus.ProcessContext.DefaultImplementation do
  @moduledoc "Process context behaviour matching the default implementation."

  @behaviour Opencensus.ProcessContext

  @impl true
  def put_span_ctx(span_ctx) do
    previous_span_ctx = get_span_ctx()
    Process.put(:oc_span_ctx_key, span_ctx)
    previous_span_ctx
  end

  @impl true
  def get_span_ctx do
    Process.get(:oc_span_ctx_key, :undefined)
  end

  @impl true
  def recover_span_ctx do
    get_span_ctx()
  end
end
