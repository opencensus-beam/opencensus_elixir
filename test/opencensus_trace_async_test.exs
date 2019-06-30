defmodule Opencensus.AsyncTest do
  use ExUnit.Case, async: false

  require Opencensus.Trace

  alias Opencensus.Span
  alias Opencensus.Trace

  test "Trace.async/1" do
    assert :ocp.current_span_ctx() == :undefined

    {inner, outer} =
      Trace.with_child_span "outside" do
        outer = :ocp.current_span_ctx() |> Span.load()

        Trace.async(fn ->
          Trace.with_child_span "inside" do
            inner = :ocp.current_span_ctx() |> Span.load()
            {inner, outer}
          end
        end)
        |> Trace.await(10)
      end

    assert inner.trace_id == outer.trace_id
    assert inner.parent_span_id == outer.span_id
    assert outer.parent_span_id == :undefined
  end

  defmodule M do
    def f(outer) do
      Trace.with_child_span "inside" do
        inner = :ocp.current_span_ctx() |> Span.load()
        {inner, outer}
      end
    end
  end

  test "Trace.async/3" do
    assert :ocp.current_span_ctx() == :undefined

    {inner, outer} =
      Trace.with_child_span "outside" do
        outer = :ocp.current_span_ctx() |> Span.load()
        Trace.async(M, :f, [outer]) |> Trace.await(10)
      end

    assert inner.trace_id == outer.trace_id
    assert inner.parent_span_id == outer.span_id
    assert outer.parent_span_id == :undefined
  end
end
