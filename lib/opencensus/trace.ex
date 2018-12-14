defmodule Opencensus.Trace do
  @doc "Wraps the given block in a tracing child span with the given label/name"
  defmacro with_child_span(label, do: block) do
    quote do
      :ocp.with_child_span(unquote(label), %{})

      try do
        unquote(block)
      after
        :ocp.finish_span()
      end
    end
  end

  @doc "Wraps the given block in a tracing child span with the given label/name and additional attributes"
  defmacro with_child_span(label, attributes, do: block) do
    quote do
      :ocp.with_child_span(unquote(label), unquote(attributes))

      try do
        unquote(block)
      after
        :ocp.finish_span()
      end
    end
  end
end
