# Opencensus

[![CircleCI](https://circleci.com/gh/opencensus-beam/opencensus_elixir.svg?style=svg)](https://circleci.com/gh/opencensus-beam/opencensus_elixir)
[![Hex version badge](https://img.shields.io/hexpm/v/opencensus_elixir.svg)](https://hex.pm/packages/opencensus_elixir)

Wraps some [`:opencensus`][:opencensus] capabilities for Elixir users so
they don't have to [learn them some Erlang][lyse] in order to get
[OpenCensus] distributed tracing.

[opencensus]: http://opencensus.io
[:opencensus]: https://hex.pm/packages/opencensus
[lyse]: https://learnyousomeerlang.com

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

## Alternatives

If you prefer driving Erlang packages directly (see also `:telemetry`), copy
what you need from `lib/opencensus/trace.ex` and call
`Logger.set_logger_metadata/0` if there's any chance of Logger use within
the span.

```elixir
def traced_fn() do
  try do
    :ocp.with_child_span("name", %{fn: :traced_fn, mod: __MODULE__})
    Logger.set_logger_metadata()

    :YOUR_CODE_HERE
  after
    :ocp.finish_span()
    Logger.set_logger_metadata()
  end
end
```

If `try .. after .. end` feels too bulky and you're _sure_ you won't need
Logger, try [`:ocp.with_child_span/3`][ocp-with_child_span-3]:

```elixir
def traced_fn() do
  :ocp.with_child_span("traced", %{fn: :traced_fn, mod: __MODULE__}, fn () ->
    :YOUR_CODE_HERE
  end)
end
```

## Troubleshooting

To see your spans, use the `:oc_reporter_stdout` reporter, either in config:

```elixir
config :opencensus, reporters: [{:oc_reporter_stdout, []}]
```

... or at the `iex` prompt:

```plain
iex> :oc_reporter.register(:oc_reporter_stdout)
```

[oce-with_child_span-3]: https://hexdocs.pm/opencensus_elixir/Opencensus.Trace.html#with_child_span/3
[ocp-with_child_span-3]: https://hexdocs.pm/opencensus/ocp.html#with_child_span-3
