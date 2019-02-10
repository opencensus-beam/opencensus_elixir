defmodule Opencensus.TraceTest do
  use ExUnit.Case
  use ExUnitProperties

  import Opencensus.Trace

  setup do
    :application.load(:opencensus)
    :application.set_env(:opencensus, :send_interval_ms, 1)
    :application.set_env(:opencensus, :reporter, {PidAttributesReporter, self()})

    Application.ensure_all_started(:opencensus)
    Application.ensure_all_started(:opencensus_elixir)

    on_exit(fn ->
      Application.stop(:opencensus)
    end)

    :ok
  end

  describe "with_child_span" do
    property "returns value of the computation" do
      check all value <- term() do
        result = with_child_span("child_span", fn -> value end)

        assert result == value
      end
    end

    test "creates new span" do
      with_child_span("child_span", fn ->
        :do_something
      end)

      assert_receive {:span, _, _}, 1_000
    end

    property "created span has provided name" do
      check all name <- string(:alphanumeric) do
        with_child_span(name, fn ->
          :do_something
        end)

        assert_receive {:span, ^name, _}, 1_000
      end
    end

    property "custom attributes are set" do
      key = one_of([string(:alphanumeric), atom(:alphanumeric)])
      value = term()

      check all attr <- map_of(key, value) do
        with_child_span("child_span", attr, fn ->
          :do_something
        end)

        assert_receive {:span, _, ^attr}, 1_000
      end
    end
  end
end
