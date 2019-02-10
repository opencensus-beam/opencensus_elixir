defmodule Opencensus.Trace do
  @doc """
  Wraps the given block in a tracing child span with the given label/name
  and optional attributes
  """
  defdelegate with_child_span(name, attributes \\ %{}, func), to: :ocp
end
