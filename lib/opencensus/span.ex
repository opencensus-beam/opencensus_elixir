defmodule Opencensus.Span do
  @moduledoc """
  Elixir convenience translation of `:opencensus.span`.

  Most likely to be of use while writing unit tests, or packages that deal with spans.
  Less likely to be of use while writing application code.
  """

  alias Opencensus.SpanContext

  require Record
  @fields Record.extract(:span, from_lib: "opencensus/include/opencensus.hrl")
  Record.defrecordp(:span, @fields)

  defstruct Keyword.keys(@fields)

  @doc "Get a span struct given a record."
  @spec from(:opencensus.span()) :: %__MODULE__{}
  def from(record) when Record.is_record(record, :span), do: struct!(__MODULE__, span(record))

  @doc "Load a span from ETS. Only works until it has been sent."
  @spec load(:opencensus.span_ctx() | integer() | :undefined) :: %__MODULE__{} | nil
  def load(span_id_or_ctx)

  def load(:undefined), do: nil

  def load(span_id) when is_integer(span_id) do
    case :ets.lookup(:oc_span_tab, span_id) do
      [record] -> from(record)
      [] -> nil
    end
  end

  def load(span_ctx) when is_tuple(span_ctx) do
    span_ctx |> SpanContext.from() |> Map.get(:span_id) |> load()
  end
end
