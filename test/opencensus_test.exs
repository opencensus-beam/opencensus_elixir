defmodule OpencensusTest do
  use ExUnit.Case

  import Opencensus.TestSupport.SpanCaptureReporter
  import Opencensus.Trace

  alias Opencensus.Span

  test "verify attributes", _state do
    attach()
    on_exit(make_ref(), &detach/0)

    assert Logger.metadata() == []
    assert Opencensus.Unstable.current_span_ctx() == :undefined

    with_child_span "child_span" do
      :do_something

      assert Opencensus.Unstable.current_span_ctx() != :undefined

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

    assert [%Span{attributes: %{"attr-1" => "value-1", module: OpencensusTest}}] = collect()

    with_child_span "child_span", [%{"attr-1" => "value-1"}, %{"attr-2" => "value-2"}] do
      :do_something
    end

    assert [%Span{attributes: %{"attr-1" => "value-1", "attr-2" => "value-2"}}] = collect()

    custom_attrs = %{"attr-1" => "value-1"}

    with_child_span "child_span", [:module, custom_attrs] do
      :do_something
    end

    assert [%Span{attributes: %{"attr-1" => "value-1", module: OpencensusTest}}] = collect()

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
                 line: line,
                 module: OpencensusTest
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
                 "a" => "b",
                 "c" => "e",
                 function: "test verify attributes/1"
               }
             }
           ] = collect()
  end
end
