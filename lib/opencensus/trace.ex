defmodule Opencensus.Trace do
  @moduledoc """
  Macros to help Elixir programmers use OpenCensus tracing.
  """

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
  with_child_span "child_span", [:module, :function, %{"custom_id" => "xxx"}] do
    :do_something
  end
  ```

  Automatic insertion of the `module`, `file`, `line`, or `function`:

    ```elixir
  with_child_span "child_span", [:module, :function, %{}] do
    :do_something
  end
  ```

  Collapsing multiple attribute maps (last wins):

    ```elixir
  with_child_span "child_span", [:function, %{"a" => "b", "c" => "d"}, %{"c" => "e"}] do
    :do_something
  end
  ```
  """

  @behaviour Opencensus.ProcessContext

  defmacro with_child_span(label, attributes \\ quote(do: %{}), do: block) do
    line = __CALLER__.line
    module = __CALLER__.module
    file = __CALLER__.file
    function = format_function(__CALLER__.function)

    computed_attributes =
      compute_attributes(attributes, %{
        line: line,
        module: module,
        file: file,
        function: function
      })

    quote do
      previous_span_ctx = Opencensus.Trace.get_span_ctx()
      parent_span_ctx = Opencensus.Trace.effective_span_ctx()

      new_span_ctx =
        :oc_trace.start_span(unquote(label), parent_span_ctx, %{
          :attributes => unquote(computed_attributes)
        })

      _ = Opencensus.Trace.put_span_ctx(new_span_ctx)
      Opencensus.Logger.set_logger_metadata()

      try do
        unquote(block)
      after
        _ = :oc_trace.finish_span(new_span_ctx)
        _ = Opencensus.Trace.put_span_ctx(previous_span_ctx)
        Opencensus.Logger.set_logger_metadata()
      end
    end
  end

  defp compute_attributes(attributes, default_attributes) when is_list(attributes) do
    {atoms, custom_attributes} = Enum.split_with(attributes, &is_atom/1)

    default_attributes = compute_default_attributes(atoms, default_attributes)

    case Enum.split_with(custom_attributes, fn
           ## map ast
           {:%{}, _, _} -> true
           _ -> false
         end) do
      {[ca_map | ca_maps], []} ->
        ## custom attributes are literal maps, merge 'em
        {:%{}, meta, custom_attributes} =
          List.foldl(ca_maps, ca_map, fn {:%{}, _, new_pairs}, {:%{}, meta, old_pairs} ->
            {:%{}, meta,
             :maps.to_list(:maps.merge(:maps.from_list(old_pairs), :maps.from_list(new_pairs)))}
          end)

        {:%{}, meta,
         :maps.to_list(:maps.merge(:maps.from_list(custom_attributes), default_attributes))}

      {_ca_maps, _other_calls} ->
        [f_ca | r_ca] = custom_attributes

        quote do
          unquote(
            List.foldl(r_ca ++ [Macro.escape(default_attributes)], f_ca, fn ca, acc ->
              quote do
                Map.merge(unquote(acc), unquote(ca))
              end
            end)
          )
        end
    end
  end

  defp compute_attributes(attributes, _default_attributes) do
    attributes
  end

  defp compute_default_attributes(atoms, default_attributes) do
    List.foldl(atoms, %{}, fn
      :default, _acc ->
        default_attributes

      atom, acc ->
        Map.put(acc, atom, Map.fetch!(default_attributes, atom))
    end)
  end

  defp format_function(nil), do: nil
  defp format_function({name, arity}), do: "#{name}/#{arity}"

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
  Put the current span context.

  Replaces `:ocp.with_span_ctx/1`.

  Callers [MAY] pass values from `get_span_ctx/0` to `put_span_ctx/1`.

  Callers [MUST NOT] pass a value obtained via `recover_span_ctx/0` to `put_span_ctx/1`.

  Uses the configured `process_context`. See also: `Opencensus.ProcessContext`.

  [MAY]: https://tools.ietf.org/html/rfc2119#section-5
  """
  @impl Opencensus.ProcessContext
  def put_span_ctx(span_ctx), do: process_context() |> apply(:put_span_ctx, [span_ctx])

  @doc """
  Get the current span context.

  Replaces `:ocp.current_span_ctx/0`, along with `recover_span_ctx/0`.

  Callers [MAY] pass values from `get_span_ctx/0` to `put_span_ctx/1`.

  Uses the configured `process_context`. See also: `Opencensus.ProcessContext`.

  [MAY]: https://tools.ietf.org/html/rfc2119#section-5
  """
  @impl Opencensus.ProcessContext
  def get_span_ctx, do: process_context() |> apply(:get_span_ctx, [])

  @doc """
  Recover the current span context by less reliable means.

  Replaces `:ocp.current_span_ctx/0`, along with `get_span_ctx/0`.

  Callers [MUST NOT] pass a value obtained via `recover_span_ctx/0` to `put_span_ctx/1`.

  Uses the configured `process_context`. See also: `Opencensus.ProcessContext`.
  """
  @impl Opencensus.ProcessContext
  def recover_span_ctx, do: process_context() |> apply(:recover_span_ctx, [])

  @doc false
  def effective_span_ctx do
    case get_span_ctx() do
      :undefined -> recover_span_ctx()
      span_ctx -> span_ctx
    end
  end

  defp process_context do
    Application.get_env(
      :opencensus,
      :process_context,
      Opencensus.ProcessContext.DefaultImplementation
    )
  end
end
