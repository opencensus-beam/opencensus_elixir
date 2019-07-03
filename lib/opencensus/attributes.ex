defmodule Opencensus.Attributes do
  @moduledoc """
  Types and functions for Opencensus-compatibile span attributes.

  To be compatible with the OpenCensus protobuf protocol, an [attribute value][AttributeValue]
  [MUST] be one of:

  * `TruncatableString`
  * `int64`
  * `bool_value`
  * `double_value`

  Some destinations are even stricter, e.g. [Datadog].

  [Datadog]: https://github.com/DataDog/documentation/blob/0564879/content/en/api/tracing/send_trace.md

  The functions in this module:

  * Flatten map values as described below
  * Convert atom keys and values to strings
  * **Drop any other values not compatible with the OpenCensus protobuf definition**
  * Return a strict `t:attribute_map/0`

  [MUST]: https://tools.ietf.org/html/rfc2119#section-1
  [MAY]: https://tools.ietf.org/html/rfc2119#section-5
  [AttributeValue]: https://github.com/census-instrumentation/opencensus-proto/blob/e2601ef/src/opencensus/proto/trace/v1/trace.proto#L331

  ### Flattening

  Map flattening uses periods (`.`) to delimit keys from nested maps. These span attributes before
  flattening:

  ```elixir
  %{
    http: %{
      host:  "localhost",
      method: "POST",
      path: "/api"
    }
  }
  ```

  ... become these after flattening:

  ```elixir
  %{
    "http.host" => "localhost",
    "http.method" => "POST",
    "http.path" => "/api",
  }
  ```
  """

  @typedoc "Attribute key."
  @type attribute_key :: String.t() | atom()

  @typedoc "Safe attribute value."
  @type attribute_value :: String.t() | atom() | boolean() | integer() | float()

  @typedoc "Map of attribute keys to safe attribute values."
  @type attribute_map :: %{attribute_key() => attribute_value()}

  @typedoc "Map of attribute keys to safe attribute values and nested attribute maps."
  @type rich_attribute_value :: attribute_value() | rich_attribute_map()

  @typedoc "Map of attribute keys to safe attribute values and nested attribute maps."
  @type rich_attribute_map :: %{attribute_key() => rich_attribute_value()}

  @typedoc "Automatic attribute key."
  @type auto_attribute_key :: :line | :module | :file | :function

  @typedoc "An attribute we can flatten into an `t:attribute_map/0`."
  @type rich_attribute ::
          {attribute_key(), rich_attribute_value()}
          | rich_attribute_map()

  @doc """
  Process span attributes after fetching bare atoms from default attributes.

      iex> process_attributes([:default, attr: 1], %{line: 1, module: __MODULE__})
      %{"line" => 1, "module" => "Opencensus.TraceTest", "attr" => 1}

      iex> process_attributes([:module, attr: 1], %{line: 1, module: __MODULE__})
      %{"module" => "Opencensus.TraceTest", "attr" => 1}
  """
  @spec process_attributes(
          attributes ::
            rich_attribute_map()
            | list(
                :default
                | auto_attribute_key()
                | rich_attribute
              ),
          default_attributes :: %{auto_attribute_key() => attribute_value()}
        ) :: attribute_map()
  def process_attributes(attributes, default_attributes)

  def process_attributes(attributes, default_attributes) when is_list(attributes) do
    attributes
    |> Enum.map(&replace_defaults(&1, default_attributes))
    |> flatten1()
    |> process_attributes()
  end

  def process_attributes(attributes, _) when is_map(attributes) do
    attributes |> process_attributes()
  end

  @doc """
  Produce default attributes for `process_attributes/2` given a macro's `__CALLER__`.
  """
  @spec default_attributes(Macro.Env.t()) :: %{auto_attribute_key() => attribute_value()}
  def default_attributes(env) when is_map(env) do
    %{
      line: env.line,
      module: env.module,
      file: env.file,
      function: format_function(env.function)
    }
  end

  defp format_function(nil), do: nil
  defp format_function({name, arity}), do: "#{name}/#{arity}"

  @doc """
  Process span attributes.

      iex> process_attributes(%{"a" => 1, "b" => %{"c" => 2}})
      %{"a" => 1, "b.c" => 2}

      iex> process_attributes(a: 1, b: 2.0, c: %{d: true, e: "NONCE"})
      %{"a" => 1, "b" => 2.0, "c.d" => true, "c.e" => "NONCE"}

      iex> process_attributes(no_pid: self(), no_list: [], no_nil: nil)
      %{}
  """
  @spec process_attributes(
          attributes ::
            rich_attribute_map() | list(rich_attribute)
        ) :: attribute_map()
  def process_attributes(attributes)

  def process_attributes(attributes) when is_list(attributes) do
    attributes
    |> Enum.map(&clean_pair/1)
    |> flatten1()
    |> Enum.into(%{})
  end

  def process_attributes(attributes) when is_map(attributes) do
    attributes |> List.wrap() |> process_attributes()
  end

  defp replace_defaults(:default, default_attributes) do
    default_attributes
  end

  defp replace_defaults(default_key, default_attributes) when is_atom(default_key) do
    [{default_key, Map.fetch!(default_attributes, default_key)}]
  end

  defp replace_defaults(value, _) do
    [value]
  end

  @spec clean_pair({attribute_key(), term()}) :: [{String.t(), attribute_value()}]
  defp clean_pair(key_value_pair)

  # If the key is an atom, convert it to a string:
  defp clean_pair({k, v}) when is_atom(k), do: {Atom.to_string(k), v} |> clean_pair()

  # If the key isn't a string, drop the pair.
  defp clean_pair({k, _}) when not is_binary(k), do: []

  # If the value is nil, drop the pair:
  defp clean_pair({_, v}) when is_nil(v), do: []

  # If the value is simple, keep it:
  defp clean_pair({k, v})
       when is_number(v) or
              is_binary(v) or
              is_boolean(v) or
              is_float(v),
       do: [{k, v}]

  # If the value is an atom, convert it to a string and remove `Elixir.`:
  defp clean_pair({k, v}) when is_atom(v),
    do: [{k, v |> Atom.to_string() |> String.replace(~r/^Elixir\./, "")}]

  # If the value is a map: flatten, nest, and clean it.
  defp clean_pair({k, map}) when is_map(map) do
    map
    |> Map.to_list()
    |> Enum.filter(fn {k, _} -> k != :__struct__ end)
    |> Enum.map(&nest(&1, k))
    |> Enum.map(&clean_pair/1)
    |> flatten1()
  end

  # If the tuple is actually a map:
  defp clean_pair(map) when is_map(map) do
    map
    |> Map.to_list()
    |> Enum.map(&clean_pair/1)
    |> flatten1()
  end

  # Give up:
  defp clean_pair(_), do: []

  defp nest({k, v}, prefix), do: {"#{prefix}.#{k}", v}

  defp flatten1(list) when is_list(list) do
    list
    |> List.foldr([], fn
      x, acc when is_list(x) -> x ++ acc
      x, acc -> [x | acc]
    end)
  end
end
