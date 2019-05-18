# Opencensus

[![CircleCI](https://circleci.com/gh/opencensus-beam/opencensus_elixir.svg?style=svg)](https://circleci.com/gh/opencensus-beam/opencensus_elixir)
[![Hex version badge](https://img.shields.io/hexpm/v/opencensus_elixir.svg)](https://hex.pm/packages/opencensus_elixir)

Wraps some [`:opencensus`][:opencensus] capabilities for Elixir users so
they don't have to [learn them some Erlang][LYSE] in order to get
[OpenCensus] distributed tracing.

[OpenCensus]: http://opencensus.io
[:opencensus]: https://hex.pm/packages/opencensus
[LYSE]: https://learnyousomeerlang.com

## Installation

Add `opencensus_elixir` to your `deps` in `mix.exs`:

```elixir
def deps do
  [
    {:opencensus, "~> 0.9"},
    {:opencensus_elixir, "~> 0.3.0"}
  ]
end
```

## Usage

Wrap your code with the
[`Opencensus.Trace.with_child_span/3`][oce-with_child_span-3] macro to
execute it in a fresh span:

```elixir
import Opencensus.Trace

def traced_fn(arg) do
  with_child_span "traced" do
    :YOUR_CODE_HERE
  end
end
```

That's the rough equivalent of the following direct use of `:opencensus`:

```elixir
def traced_fn() do
  try do
    :ocp.with_child_span("traced", %{fn: :traced_fn, mod: __MODULE__})
    {:span_ctx, trace_id, span_id, trace_options, _} = :ocp.current_span_ctx()

    Logger.metadata(
      trace_id: :io_lib.format("~32.16.0b", [trace_id]) |> List.to_string(),
      span_id: :io_lib.format("~16.16.0b", [span_id]) |> List.to_string(),
      trace_options: trace_options
    )

    :YOUR_CODE_HERE
  after
    :ocp.finish_span()
    Logger.metadata(trace_id: nil, span_id: nil, trace_options: nil)
  end
end
```

The `Logger.metadata/1` work won't be necessary in an Elixir version later
than 1.9: unifying the metadata between `:logger` and `Logger` will require
Erlang 21 or better. If that has already happened, you'll see the metadata
repeated at the `iex` prompt if you paste this in:

```elixir
:ocp.with_child_span("traced")
:logger.get_process_metadata()
Logger.metadata(()
```

Until then, you [SHOULD] call `Opencensius.Trace.set_logger_metadata/0`
after using functions in [`:ocp`] to manipulate the span context stored in
the process dictionary.

[:ocp]: https://hexdocs.pm/opencensus/ocp.html
[SHOULD]: https://tools.ietf.org/html/rfc2119#section-3

Back to _your_ code: you can save yourself the `try .. after .. end` with
[`:ocp.with_child_span/3`][ocp-with_child_span-3], at the expense of
having to wrap your work in an anonymous expression. If you're also sure you
won't use `Logger` or its metadata, that's easier, but not _quite_ as easy
as using the macro:

```elixir
def traced_fn() do
  :ocp.with_child_span("traced", %{fn: :traced_fn, mod: __MODULE__}, fn () ->
    :do_something
  end)
end
```

To see your spans, use the `:oc_reporter_stdout` reporter, either in config:

```elixir
config :opencensus, reporters: [{:oc_reporter_stdout, []}]
```

... or at the `iex` prompt:

    iex> :oc_reporter.register(:oc_reporter_stdout)

[oce-with_child_span-3]: https://hexdocs.pm/opencensus_elixir/Opencensus.Trace.html#with_child_span/3
[ocp-with_child_span-3]: https://hexdocs.pm/opencensus/ocp.html#with_child_span-3
