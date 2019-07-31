defmodule Opencensus.TestSupport.SpanCaptureReporterTest do
  use ExUnit.Case, async: false
  import Opencensus.Trace

  alias Opencensus.TestSupport.SpanCaptureReporter

  describe "Opencensus.TestSupport.SpanCaptureReporter.collect/3" do
    defp loop_count do
      case System.get_env("CI") do
        nil -> 10
        _ -> 1000
      end
    end

    test "before detach, gets the just-finished span" do
      for _ <- 1..loop_count() do
        SpanCaptureReporter.attach()

        with_child_span "inner" do
          [0, 1, 1, 2, 2, 2, 2, 3, 3, 4] |> Enum.random() |> :timer.sleep()
          :...
        end

        assert SpanCaptureReporter.collect() |> length() == 1
        SpanCaptureReporter.detach()
      end
    end

    test "after detach, gets the just-finished span" do
      for _ <- 1..loop_count() do
        SpanCaptureReporter.attach()

        with_child_span "inner" do
          [0, 1, 1, 2, 2, 2, 2, 3, 3, 4] |> Enum.random() |> :timer.sleep()
          :...
        end

        SpanCaptureReporter.detach()
        assert SpanCaptureReporter.collect() |> length() == 1
      end
    end
  end
end
