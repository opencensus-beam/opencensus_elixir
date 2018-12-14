defmodule Opencensus.Trace do
  @doc "Wraps the given block in a tracing child span with the given label/name and optional attributes"
  defmacro with_child_span(label, attributes \\ quote(do: %{}), do: block) do
    quote do
      parent_span_ctx = :ocp.current_span_ctx()
      new_span_ctx = :oc_trace.start_span(unquote(label), parent_span_ctx, unquote(attributes))
      :ocp.with_span_ctx(new_span_ctx)

      try do
        unquote(block)
      after
        :oc_trace.finish_span(new_span_ctx)
        :ocp.with_span_ctx(parent_span_ctx)
      end
    end
  end
end
