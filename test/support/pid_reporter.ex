defmodule PidAttributesReporter do
  require Record

  Record.defrecordp(:span, Record.extract(:span, from_lib: "opencensus/include/opencensus.hrl"))

  def init(pid), do: pid

  def report(spans, pid) do
    Enum.each(spans, fn span ->
      send(pid, {:span, span(span, :name), span(span, :attributes)})
    end)
  end
end
