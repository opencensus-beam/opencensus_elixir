defmodule Opencensus.Trace do
  @moduledoc """
  Macros and functions to help Elixir programmers use OpenCensus tracing.
  """

  alias Opencensus.Attributes

  @doc """
  Wrap the given block in a child span with the given label/name and optional attributes.

  Sets `Logger.metadata/0` with `Opencensus.Logger.set_logger_metadata/0` after changing the span
  context tracked in the process dictionary.

  No attributes:

  ```elixir
  with_child_span "child_span" do
    :do_something
  end

  with_child_span "child_span", %{} do
    :do_something
  end
  ```

  Custom attributes:

  ```elixir
  with_child_span "child_span", [user_id: "xxx", %{"custom_id" => "xxx"}] do
    :do_something
  end
  ```

  Automatic insertion of the `module`, `file`, `line`, or `function`:

    ```elixir
  with_child_span "child_span", [:module, :function, user_id: "xxx"] do
    :do_something
  end
  ```

  Collapsing multiple attribute maps (last wins):

    ```elixir
  with_child_span "child_span", [:function, %{"a" => "b", "c" => "d"}, %{"c" => "e"}] do
    :do_something
  end
  ```

  Attributes incompatible with the Opencensus wire protocol will be dropped. See
  `Attributes.process_attributes/2` for more detail.
  """
  defmacro with_child_span(label, attrs \\ quote(do: []), do: block) do
    default_attributes = __CALLER__ |> Attributes.default_attributes() |> Macro.escape()

    quote do
      attributes = Attributes.process_attributes(unquote(attrs), unquote(default_attributes))
      parent_span_ctx = :ocp.current_span_ctx()

      new_span_ctx =
        :oc_trace.start_span(unquote(label), parent_span_ctx, %{attributes: attributes})

      _ = :ocp.with_span_ctx(new_span_ctx)
      Opencensus.Logger.set_logger_metadata()

      try do
        unquote(block)
      after
        _ = :oc_trace.finish_span(new_span_ctx)
        _ = :ocp.with_span_ctx(parent_span_ctx)
        Opencensus.Logger.set_logger_metadata()
      end
    end
  end

  @doc """
  Drop-in replacement for `Task.async/1` that propagates the process' span context.

  Does NOT start a new span for what's inside. Consider `with_child_span/3`.
  """
  @spec async((() -> any())) :: Task.t()
  def async(fun) when is_function(fun, 0) do
    async(:erlang, :apply, [fun, []])
  end

  @doc """
  Drop-in replacement for `Task.async/3` that propagates the process' span context.

  Does NOT start a new span for what's inside. Consider `with_child_span/3`.
  """
  @spec async(module(), atom(), [term()]) :: Task.t()
  def async(module, function_name, args)
      when is_atom(module) and is_atom(function_name) and is_list(args) do
    original_span_ctx = :ocp.current_span_ctx()

    wrapper = fn ->
      :ocp.with_span_ctx(original_span_ctx)
      apply(module, function_name, args)
    end

    Task.async(wrapper)
  end

  @doc """
  Drop-in replacement for `Task.await/2`.
  """
  @spec await(Task.t(), :infinity | pos_integer()) :: term()
  defdelegate await(task, timeout \\ 5000), to: Task

  @doc """
  Put additional attributes to the current span.

  Attributes incompatible with the Opencensus wire protocol will be dropped. See
  `Attributes.process_attributes/2` for more detail.
  """
  @spec put_span_attributes(Attributes.rich_attribute_map() | list(Attributes.rich_attribute())) ::
          true
  def put_span_attributes(attrs) when is_list(attrs) or is_map(attrs) do
    attrs
    |> Attributes.process_attributes()
    |> :ocp.put_attributes()
  end
end
