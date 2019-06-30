defmodule Opencensus.TraceTest do
  use ExUnit.Case, async: false

  import Opencensus.Attributes
  import Opencensus.TestSupport.SpanCaptureReporter
  import Opencensus.Trace

  alias Opencensus.Span

  doctest Opencensus.Attributes

  test "verify attributes", _state do
    attach()
    on_exit(make_ref(), &detach/0)

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

    assert [%Span{attributes: %{}}] = collect()

    with_child_span "child_span", %{"attr-1" => "value-1"} do
      :do_something
    end

    assert [%Span{attributes: %{"attr-1" => "value-1"}}] = collect()

    with_child_span "child_span", [:module, %{"attr-1" => "value-1"}] do
      :do_something
    end

    assert [%Span{attributes: %{"attr-1" => "value-1", "module" => "Opencensus.TraceTest"}}] =
             collect()

    with_child_span "child_span", [%{"attr-1" => "value-1"}, %{"attr-2" => "value-2"}] do
      :do_something
    end

    assert [%Span{attributes: %{"attr-1" => "value-1", "attr-2" => "value-2"}}] = collect()

    custom_attrs = %{"attr-1" => "value-1"}

    with_child_span "child_span", [:module, custom_attrs] do
      :do_something
    end

    assert [%Span{attributes: %{"attr-1" => "value-1", "module" => "Opencensus.TraceTest"}}] =
             collect()

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

    assert [
             %Span{
               attributes: %{
                 "attr" => "value",
                 "attr-1" => "value-1",
                 "attr-2" => "value-2",
                 "module" => "Opencensus.TraceTest",
                 "line" => line
               }
             }
           ] = collect()

    assert is_integer(line)

    with_child_span "child_span", [:function, %{"a" => "b", "c" => "d"}, %{"c" => "e"}] do
      :do_something
    end

    assert [
             %Span{
               attributes: %{
                 "function" => "test verify attributes/1",
                 "a" => "b",
                 "c" => "e"
               }
             }
           ] = collect()
  end
end
