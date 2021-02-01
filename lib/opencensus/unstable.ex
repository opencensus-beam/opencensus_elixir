defmodule Opencensus.Unstable do
  @moduledoc """
  Experimental higher-level API built on proposed `ot_ctx` behaviour.
  """

  @doc """
  Get the current span context.

  Uses the first configured `process_context` only to ensure the value is safe to pass to
  `with_span_ctx/1` and `with_span_ctx/2` after you've finished your work.
  """
  @spec current_span_ctx() :: :opencensus.span_ctx() | :undefined
  def current_span_ctx do
    process_contexts()
    |> hd
    |> get_span_ctx_via()
  end

  @doc """
  Recovers the span context.

  Uses all configured `process_context`.
  Results MAY be used as the parent of a new span.
  Results MUST NOT be passed to `with_span_ctx/1` or `with_span_ctx/2`.
  """
  @spec recover_span_ctx() :: :opencensus.span_ctx() | :undefined
  def recover_span_ctx do
    process_contexts()
    |> Enum.find_value(:undefined, &get_span_ctx_via/1)
  end

  @doc """
  Sets the span context. Replaces `:ocp.with_span_ctx/1`.

  Uses all configured `process_context`.
  Returns the previous value of `current_span_ctx/0`.
  """
  @spec with_span_ctx(span_ctx :: :opencensus.span_ctx() | :undefined) ::
          :opencensus.span_ctx() | :undefined
  def with_span_ctx(span_ctx) do
    return_span_ctx = current_span_ctx()
    process_contexts() |> Enum.each(&put_span_ctx_via(&1, span_ctx))
    return_span_ctx
  end

  defp get_span_ctx_via(module) do
    apply(module, :get, [span_ctx_key()])
    |> case do
      nil -> :undefined
      span_ctx -> span_ctx
    end
  end

  defp put_span_ctx_via(module, value) do
    apply(module, :with_value, [span_ctx_key(), value])
  end

  @spec span_ctx_key() :: atom()
  defp span_ctx_key do
    Application.get_env(:opencensus, :span_ctx_key, :oc_span_ctx_key)
  end

  @spec process_contexts() :: list(module())
  defp process_contexts do
    Application.get_env(:opencensus, :process_contexts, [
      Opencensus.Unstable.ProcessContext.SeqTrace,
      Opencensus.Unstable.ProcessContext.ProcessDictionary,
      Opencensus.Unstable.ProcessContext.ProcessDictionaryWithRecovery
    ])
  end
end

defmodule Opencensus.Unstable.ProcessContext do
  @moduledoc "Abstraction over process-local storage."

  @doc "Get a value."
  @callback get(key :: atom()) :: any() | nil

  @doc "Put a value."
  @callback with_value(key :: atom, value :: any()) :: :ok
end

defmodule Opencensus.Unstable.ProcessContext.SeqTrace do
  @moduledoc """
  Process-local storage using `seq_trace`.

  Shares well with any other use that maintains a namespace in the second element of a 2-tuple
  `{:shared_label, _map}`. Otherwise leaves the trace label alone to avoid disrupting the other
  usage.
  """

  @behaviour Opencensus.Unstable.ProcessContext

  @doc "Get a value from the shared `seq_trace` label."
  @impl Opencensus.Unstable.ProcessContext
  def get(key) do
    case :seq_trace.get_token(:label) do
      {:label, {:shared_label, %{^key => value}}} ->
        value

      _ ->
        nil
    end
  end

  @doc "Put a value to the shared `seq_trace` label if safe."
  @impl Opencensus.Unstable.ProcessContext
  def with_value(key, value) do
    case :seq_trace.get_token(:label) do
      [] ->
        :seq_trace.set_token(:label, {:shared_label, %{key => value}})

      {:label, {:shared_label, map}} when is_map(map) ->
        :seq_trace.set_token(:label, {:shared_label, Map.put(map, key, value)})

      _ ->
        nil
    end

    :ok
  end
end

defmodule Opencensus.Unstable.ProcessContext.ProcessDictionary do
  @moduledoc """
  Process-local storage using the process dictionary.
  """

  @behaviour Opencensus.Unstable.ProcessContext

  @doc "Get a value from the process dictionary."
  @impl Opencensus.Unstable.ProcessContext
  def get(key), do: Process.get(key)

  @impl Opencensus.Unstable.ProcessContext
  def with_value(key, value) do
    Process.put(key, value)
    :ok
  end
end

defmodule Opencensus.Unstable.ProcessContext.ProcessDictionaryWithRecovery do
  @moduledoc """
  Process-local storage using the process dictionary.
  """

  @behaviour Opencensus.Unstable.ProcessContext

  @doc "Get a value from the process dictionary."
  @impl Opencensus.Unstable.ProcessContext
  def get(key) do
    [self() | Process.get(:"$callers", [])]
    |> Enum.find_value(fn pid -> pid |> Process.info() |> get_in([:dictionary, key]) end)
  end

  @impl Opencensus.Unstable.ProcessContext
  defdelegate with_value(key, value), to: Opencensus.Unstable.ProcessContext.ProcessDictionary
end
