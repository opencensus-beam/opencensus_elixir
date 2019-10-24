defmodule Opencensus.MetricsTest do
  alias Opencensus.Metrics
  alias Opencensus.TestSupport.MetricsCaptureExporter, as: Capture

  use ExUnit.Case, async: false

  describe "Aggregate measurements" do
    test "counter" do
      measure_name = :measure1
      tag_names = [:t1, :t2]
      Metrics.new(measure_name, "A test measure", :milli_second)

      Metrics.aggregate_count(
        :test_count,
        measure_name,
        "A counter",
        tag_names
      )

      record_measures(measure_name)

      %{
        data: %{rows: rows, type: :count},
        description: "A counter",
        tags: tags,
        name: :test_count
      } = capture_aggregate(:test_count)

      expected_rows = [
        %{tags: ["A", "a"], value: 2},
        %{tags: ["B", "b"], value: 3}
      ]

      assert tags == [:t2, :t1]
      assert Enum.sort(expected_rows) == Enum.sort(rows)
    end

    test "gauge" do
      measure_name = :measure2
      Metrics.new(measure_name, "A test measure", :milli_seconds)

      Metrics.aggregate_gauge(:test_gauge, measure_name, "A gauge", [:t1, :t2])

      record_measures(measure_name)

      %{
        data: %{rows: rows, type: :latest},
        description: "A gauge",
        tags: tags,
        name: :test_gauge
      } = capture_aggregate(:test_gauge)

      expected_rows = [
        %{tags: ["A", "a"], value: 20},
        %{tags: ["B", "b"], value: 51}
      ]

      assert tags == [:t2, :t1]
      assert Enum.sort(expected_rows) == rows
    end

    test "sum" do
      measure_name = :measure3
      Metrics.new(measure_name, "A test measure", :milli_seconds)
      Metrics.aggregate_sum(:test_sum, measure_name, "A sum", [:t1, :t2])

      record_measures(measure_name)

      %{
        data: %{rows: rows, type: :sum},
        description: "A sum",
        tags: tags,
        name: :test_sum
      } = capture_aggregate(:test_sum)

      expected_rows = [
        %{tags: ["A", "a"], value: %{count: 2, sum: 30, mean: 15.0}},
        %{tags: ["B", "b"], value: %{count: 3, sum: 114, mean: 38.0}}
      ]

      assert tags == [:t2, :t1]
      assert Enum.sort(expected_rows) == rows
    end

    test "distribution" do
      measure_name = :measure4
      Metrics.new(measure_name, "A test measure", :milli_seconds)

      Metrics.aggregate_distribution(
        :test_distribution,
        measure_name,
        "A distribution",
        [:t1, :t2],
        [0, 10, 20, 30, 40, 50]
      )

      record_measures(measure_name)

      %{
        data: %{rows: rows, type: :distribution},
        description: "A distribution",
        tags: tags,
        name: :test_distribution
      } = capture_aggregate(:test_distribution)

      expected_rows = [
        %{
          tags: ["A", "a"],
          value: %{
            count: 2,
            sum: 30,
            mean: 15.0,
            buckets: [{0, 0}, {10, 1}, {20, 1}, {30, 0}, {40, 0}, {50, 0}, {:infinity, 0}]
          }
        },
        %{
          tags: ["B", "b"],
          value: %{
            count: 3,
            sum: 114,
            mean: 38.0,
            buckets: [{0, 0}, {10, 0}, {20, 0}, {30, 0}, {40, 2}, {50, 0}, {:infinity, 1}]
          }
        }
      ]

      assert tags == [:t2, :t1]
      assert Enum.sort(expected_rows) == rows
    end
  end

  describe "using tags from process dictionary" do
    test "tag values are taken from process dictionary" do
      :ocp.with_tags(%{tag: "value"})
      Metrics.new(:measure10, "measure", :bytes)

      Metrics.aggregate_count(
        :measure10_count,
        :measure10,
        "some other measure",
        [:tag]
      )

      Metrics.record(:measure10, 1)

      assert %{data: %{rows: [%{tags: ["value"]}]}, tags: [:tag]} =
               capture_aggregate(:measure10_count)
    end
  end

  describe "create measure more than once" do
    test "measurements should not be lost" do
      Metrics.new(:dup, "", :seconds)

      Metrics.aggregate_count("dup_count", :dup, "dup count", [])

      Metrics.record(:dup, 1)

      Metrics.new(:dup, "", :seconds)

      Metrics.record(:dup, 1)

      assert %{data: %{rows: [%{value: 2}]}} = capture_aggregate("dup_count")
    end
  end

  defp record_measures(measure_name) when is_atom(measure_name) do
    Metrics.record([{measure_name, 10}, {measure_name, 20}], %{t1: "a", t2: "A"})
    Metrics.record(measure_name, 31, %{t1: "b", t2: "B"})
    Metrics.record(measure_name, 32, %{t1: "b", t2: "B"})
    Metrics.record(measure_name, 51, %{t1: "b", t2: "B"})
  end

  defp capture_aggregate(name) do
    Capture.capture_next()
    |> Enum.find(fn
      %{name: ^name} -> true
      _ -> false
    end)
  end
end
