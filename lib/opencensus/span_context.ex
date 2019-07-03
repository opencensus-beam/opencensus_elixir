defmodule Opencensus.SpanContext do
  @moduledoc """
  Elixir convenience translation of `:opencensus.span_ctx`.

  Most likely to be of use while writing unit tests, or packages that deal with spans.
  Less likely to be of use while writing application code.
  """

  require Record
  @fields Record.extract(:span_ctx, from_lib: "opencensus/include/opencensus.hrl")
  Record.defrecordp(:span_ctx, @fields)

  defstruct Keyword.keys(@fields)

  @doc """
  Convert a span context.

      iex> :opencensus.span_ctx()
      :undefined
      iex> :opencensus.span_ctx() |> Opencensus.SpanContext.from()
      nil

      iex> trace_id = 158162877550332985110351567058860353513
      iex> span_id = 13736401818514315360
      iex> span_ctx = {:span_ctx, trace_id, span_id, 1, :undefined}
      iex> Opencensus.SpanContext.from(span_ctx)
      %Opencensus.SpanContext{
        span_id: 13736401818514315360,
        trace_id: 158162877550332985110351567058860353513,
        trace_options: 1,
        tracestate: :undefined
      }
  """
  @spec from(:opencensus.span_ctx() | :undefined) :: %__MODULE__{}
  def from(record)

  def from(record) when Record.is_record(record, :span_ctx),
    do: struct!(__MODULE__, span_ctx(record))

  def from(:undefined), do: nil

  @doc "Return the 32-digit hex representation of a trace ID."
  @spec hex_trace_id(:undefined | integer()) :: String.t()
  def hex_trace_id(trace_id)

  def hex_trace_id(n) when is_integer(n) and n > 0,
    do: :io_lib.format("~32.16.0b", [n]) |> to_string()

  def hex_trace_id(_), do: nil

  @doc "Return the 16-digit hex representation of a span ID."
  @spec hex_span_id(:undefined | integer()) :: String.t()
  def hex_span_id(span_id)

  def hex_span_id(n) when is_integer(n) and n > 0,
    do: :io_lib.format("~16.16.0b", [n]) |> to_string()

  def hex_span_id(_), do: nil
end
