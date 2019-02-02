defmodule Span do
  require Record
  Record.defrecord(:span, Record.extract(:span, from_lib: "opencensus/include/opencensus.hrl"))
end

defmodule PidAttributesReporter do
  import Span

  def init(pid) do
    pid
  end

  def report(spans, pid) do
    Enum.each(spans, fn span ->
      send(pid, {:attributes, span(span, :attributes)})
    end)
  end
end

defmodule OpencensusTest do
  use ExUnit.Case
  import Opencensus.Trace

  test "verify attributes", _state do
    :application.load(:opencensus)
    :application.set_env(:opencensus, :send_interval_ms, 1)
    :application.set_env(:opencensus, :reporter, {PidAttributesReporter, self()})

    :application.ensure_all_started(:opencensus)
    :application.ensure_all_started(:opencensus_elixir)

    with_child_span "child_span", default_attributes(%{"attr-1" => "value-1"}) do
      :do_something
    end

    assert_receive {:attributes, %{"attr-1" => "value-1", :module => OpencensusTest}}, 1_000
  end
end
