defmodule Opencensus.Metrics do
  @moduledoc """
  Functions to help Elixir programmers use OpenCensus metrics.

  First, a measure must be created:
  ```elixir
  Metrics.new(:name, "description", :unit)
  Metrics.new(:another, "", :unit)
  ```

  Next step is to choose aggregations to be exported:
  ```elixir
  Metrics.aggregate_count(:name_count, :name, "count", [:tag1, :tag2])
  Metrics.aggregate_gauge(:name_gauge, :name, "gauge", [:tag1, :tag2])
  Metrics.aggregate_sum(:name_sum, :name, "sum", [:tag1, :tag2])
  Metrics.aggregate_distribution(:name_distribution, :name, "distribution", [:tag1, :tag2], [0, 100, 1000])
  ```

  After aggregations are decided, measures may be recorded by explicitly providing tags:
  ```elixir
  Metrics.record(:name, %{tag1: "v1", tag2: "v2"}, 3)
  Metrics.record([another: 1, name: 100], %{tag1: "v1", tag2: "v2})
  ```
  or using tag values that are present in process dictionary:
  ```elixir
  Metrics.record(:name, 3)
  ```
  """

  defdelegate new(name, description, unit), to: :oc_stat_measure

  @doc """
  count of how many times `measure` was recorded will be exported
  """
  def aggregate_count(name, measure, description, tags) do
    :oc_stat_view.subscribe(name, measure, description, tags, :oc_stat_aggregation_count)
  end

  @doc """
  only latest recorded value of `measure` will be exported
  """
  def aggregate_gauge(name, measure, description, tags) do
    :oc_stat_view.subscribe(name, measure, description, tags, :oc_stat_aggregation_latest)
  end

  @doc """
  sum of all recorded values of `measure` will be exported
  """
  def aggregate_sum(name, measure, description, tags) do
    :oc_stat_view.subscribe(name, measure, description, tags, :oc_stat_aggregation_sum)
  end

  @doc """
  distribution of all recorded values of `measure` across all `buckets` will be exported
  """
  def aggregate_distribution(name, measure, description, tags, buckets) do
    :oc_stat_view.subscribe(
      name,
      measure,
      description,
      tags,
      {:oc_stat_aggregation_distribution, buckets: buckets}
    )
  end

  @doc """
  records single measure
  """
  def record(measure, %{} = tags, value) when is_number(value) do
    :oc_stat.record(tags, measure, value)
  end

  @doc """
  records multiple measures
  """
  def record(measures, %{} = tags) when is_list(measures) do
    :oc_stat.record(tags, measures)
  end

  @doc """
  records single measure, takes tags from process dictionary
  """
  def record(measure, value) when is_atom(measure) and is_number(value) do
    :ocp.record(measure, value)
  end
end
