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
        result = with_child_span("child_span", do: value)

        assert result == value
      end
    end

    test "creates new span" do
      with_child_span "child_span" do
        :do_something
      end

      assert_receive {:span, _, _}, 1_000
    end

    property "created span has provided name" do
      check all name <- string(:alphanumeric) do
        with_child_span name do
          :do_something
        end

        assert_receive {:span, ^name, _}, 1_000
      end
    end

    property "custom attributes are set" do
      check all key <- one_of([string(:alphanumeric), atom(:alphanumeric)]),
                value <- term() do
        with_child_span "child_span", %{key => value} do
          :do_something
        end

        assert_receive {:span, _, %{^key => ^value}}, 1_000
      end
    end

    test "contains default attributes" do
      with_child_span "child_span" do
        :do_something
      end

      assert_receive {:span, _, %{module: mod, line: _, file: file, function: function}},
                     1_000

      {func, arity} = __ENV__.function

      assert mod == __MODULE__
      assert file == __ENV__.file
      assert function == "#{func}/#{arity}"
    end

    property "skips niled out defauts" do
      props =
        ~w[line module file function]a
        |> Enum.map(&constant/1)

      check all key <- one_of(props) do
        with_child_span "child_span", %{key => nil} do
          :do_something
        end

        assert_receive {:span, _, attr}, 1_000
        refute Map.has_key?(attr, key)
      end
    end
  end
end
