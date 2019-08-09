defmodule Opencensus.TestSupport.SpanCaptureReporter do
  @moduledoc """
  An `:opencensus.reporter` to capture spans for tests.

  `:oc_reporter` can't unregister reporters, but `:telemetry` can detach handlers, so we configure
  `:opencensus` to send spans to use our reporter, in `mix.exs`:

  ```elixir
  if Mix.env() == :test do
    config :opencensus,
      send_interval_ms: 100,
      reporters: [{Opencensus.TestSupport.SpanCaptureReporter, []}]
  end
  ```

  It'll call `:telemetry.execute/3` whenever spans are reported. If you've called `attach/0`,
  the handler will convert the spans to structs with `Span.from/1` and deliver them to your
  process inbox. To collect them, call `collect/0`. When you're finished, call `detach/0`:

  ```elixir
  defmodule NyApp.SpanCaptureTest do
    use ExUnit.Case, async: false

    alias Opencensus.TestSupport.SpanCaptureReporter

    setup do
      SpanCaptureReporter.attach()
      on_exit(make_ref(), &SpanCaptureReporter.detach/0)
    end

    test "can gather spans" do
      :ocp.with_child_span("our span name")
      :ocp.finish_span()
      [span] = SpanCaptureReporter.collect()
      assert span.name == "our span name"
    end
  end
  ```
  """

  alias Opencensus.Span

  @behaviour :oc_reporter

  @impl true
  def init([]), do: []

  @impl true
  def report(spans, []) do
    :telemetry.execute([__MODULE__], %{}, %{spans: spans})
    :ok
  end

  @doc false
  def handler([__MODULE__], %{}, %{spans: spans}, {pid, attached_monotonic}) do
    started_after_attach? = fn span -> span |> Span.began_monotonic() >= attached_monotonic end
    filtered = spans |> Enum.filter(started_after_attach?)
    send(pid, {:spans, filtered})
  end

  @doc "Attach the reporter to deliver spans to your process inbox."
  def attach do
    :telemetry.attach(__MODULE__, [__MODULE__], &handler/4, {self(), :erlang.monotonic_time()})
  end

  @doc """
  Detach the reporter to stop delivering spans to your process inbox.

  If still attached, triggers span delivery before detaching.
  """
  def detach do
    if handler_attached?(), do: trigger_and_wait_for_span_delivery()
    :telemetry.detach(__MODULE__)
  end

  @doc """
  Collect spans from your process inbox.

  If still attached, triggers span delivery before collection.
  """
  @spec collect() :: list(%Span{})
  def collect do
    if handler_attached?(), do: trigger_and_wait_for_span_delivery()
    collect_span_records([]) |> Enum.map(&Span.from/1)
  end

  defp trigger_and_wait_for_span_delivery do
    send(:oc_reporter, :report_spans)
    :timer.sleep(1)
  end

  defp handler_attached? do
    :telemetry.list_handlers([__MODULE__]) != []
  end

  defp collect_span_records(acc) when is_list(acc) do
    receive do
      {:spans, spans} -> collect_span_records(acc ++ spans)
    after
      1 -> acc
    end
  end
end
