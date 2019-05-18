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
    :application.set_env(:opencensus, :reporters, [{PidAttributesReporter, self()}])

    :application.ensure_all_started(:opencensus)
    :application.ensure_all_started(:opencensus_elixir)

    assert Logger.metadata() == []
    assert :ocp.current_span_ctx() == :undefined

    with_child_span "child_span" do
      :do_something

      assert :ocp.current_span_ctx() != :undefined

      assert Logger.metadata() |> Keyword.keys() |> Enum.sort() == [
               :span_id,
               :trace_id,
               :trace_options
             ]
    end

    assert_receive {:attributes, %{}}, 1_000

    with_child_span "child_span", %{"attr-1" => "value-1"} do
      :do_something
    end

    assert_receive {:attributes, %{"attr-1" => "value-1"}}, 1_000

    with_child_span "child_span", [:module, %{"attr-1" => "value-1"}] do
      :do_something
    end

    assert_receive {:attributes, %{"attr-1" => "value-1", :module => OpencensusTest}}, 1_000

    with_child_span "child_span", [%{"attr-1" => "value-1"}, %{"attr-2" => "value-2"}] do
      :do_something
    end

    assert_receive {:attributes, %{"attr-1" => "value-1", "attr-2" => "value-2"}}, 1_000

    custom_attrs = %{"attr-1" => "value-1"}

    with_child_span "child_span", [:module, custom_attrs] do
      :do_something
    end

    assert_receive {:attributes, %{"attr-1" => "value-1", :module => OpencensusTest}}, 1_000

    custom_attrs1 = %{"attr-1" => "value-1"}
    custom_attrs2 = %{"attr-2" => "value-2"}

    with_child_span "child_span", [
      :module,
      %{"attr" => "value"},
      custom_attrs1,
      :line,
      custom_attrs2
    ] do
      :do_something
    end

    assert_receive {:attributes,
                    %{
                      "attr" => "value",
                      "attr-1" => "value-1",
                      "attr-2" => "value-2",
                      :module => OpencensusTest,
                      :line => _
                    }},
                   1_000
  end
end
