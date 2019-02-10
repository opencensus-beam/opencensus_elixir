defmodule Opencensus.Stat do
  def record(name, value, tags \\ %{}),
    do: :oc_stat.record(tags, name, value)
end
