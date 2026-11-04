defmodule Juliet.XML do
  @moduledoc """
  Provides functions for building and inspecting XML stanzas.

  Juliet preserves the public tuple shape that Romeo exposed via `fast_xml`:

    * `{:xmlel, name :: binary, attrs :: [{binary, binary}], children :: [tuple]}`
    * `{:xmlcdata, content :: binary}`
    * `{:xmlstreamstart, name :: binary, attrs :: [{binary, binary}]}`
    * `{:xmlstreamend, name :: binary}`

  The records below are private to the macro and are kept only to minimize
  churn in downstream code.
  """

  require Record

  defmacro __using__(_opts) do
    quote do
      use Juliet.XMLNS
      require Record
      alias Juliet.Stanza
      alias Juliet.Stanza.IQ
      alias Juliet.Stanza.Message
      alias Juliet.Stanza.Presence

      Record.defrecordp(:xmlel, name: "", attrs: [], children: [])
      Record.defrecordp(:xmlcdata, content: [])
      Record.defrecordp(:xmlstreamstart, name: "", attrs: [])
      Record.defrecordp(:xmlstreamend, name: "")
    end
  end

  @type element :: {:xmlel, binary, [{binary, binary}], [child]}
  @type cdata :: {:xmlcdata, binary}
  @type stream_start :: {:xmlstreamstart, binary, [{binary, binary}]}
  @type stream_end :: {:xmlstreamend, binary}
  @type child :: element | cdata | binary

  @doc """
  Encodes a stanza tuple or struct into an XML binary.
  """
  @spec encode(term) :: binary
  def encode({:xmlel, name, attrs, []}) do
    "<#{name}#{attrs_to_string(attrs)}/>"
  end

  def encode({:xmlel, name, attrs, children}) do
    "<#{name}#{attrs_to_string(attrs)}>#{encode_children(children)}</#{name}>"
  end

  def encode({:xmlstreamstart, name, attrs}) do
    "<#{name}#{attrs_to_string(attrs)}>"
  end

  def encode({:xmlstreamend, name}) do
    "</#{name}>"
  end

  def encode({:xmlcdata, content}) do
    escape_cdata(content)
  end

  def encode(stanza), do: Juliet.Stanza.to_xml(stanza)

  @doc """
  Same as `encode/1`. Kept for compatibility with the old `fast_xml` API.
  """
  def encode!(stanza), do: encode(stanza)

  defp attrs_to_string(attrs) do
    Enum.map_join(attrs, "", fn {k, v} -> " #{k}='#{escape_attr(v)}'" end)
  end

  defp encode_children(children) do
    Enum.map_join(children, "", &encode_child/1)
  end

  defp encode_child({:xmlel, _, _, _} = el), do: encode(el)
  defp encode_child({:xmlcdata, content}), do: escape_cdata(content)
  defp encode_child(binary) when is_binary(binary), do: escape_text(binary)
  defp encode_child(_), do: ""

  defp escape_text(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp escape_attr(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("'", "&apos;")
  end

  defp escape_cdata(content) do
    content
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  @doc """
  Returns the given attribute value or default.
  """
  def attr(element, name, default \\ nil)

  def attr({:xmlel, _, attrs, _}, name, default) do
    case List.keyfind(attrs, name, 0) do
      {^name, value} -> value
      nil -> default
    end
  end

  def attr(_, _name, default), do: default

  @doc """
  Returns the first child element with the given name, or default.
  """
  def subelement(element, name, default \\ nil)

  def subelement({:xmlel, _, _, children}, name, default) do
    Enum.find(children, default, fn
      {:xmlel, ^name, _, _} -> true
      _ -> false
    end)
  end

  def subelement(_, _name, default), do: default

  @doc """
  Returns all child elements with the given name.
  """
  def subelements({:xmlel, _, _, children}, name) do
    Enum.filter(children, fn
      {:xmlel, ^name, _, _} -> true
      _ -> false
    end)
  end

  def subelements(_, _name), do: []

  @doc """
  Returns the concatenated character data of an element.
  """
  def cdata(nil), do: ""

  def cdata({:xmlel, _, _, children}) do
    children
    |> Enum.map(&cdata/1)
    |> IO.iodata_to_binary()
  end

  def cdata({:xmlcdata, content}), do: content
  def cdata(binary) when is_binary(binary), do: binary
  def cdata(_), do: ""

  @doc """
  Parses a complete XML fragment into the Juliet tuple format.
  """
  def parse_element(xml) when is_binary(xml) do
    case Saxy.SimpleForm.parse_string(xml, cdata_as_characters: false) do
      {:ok, {name, attrs, children}} ->
        {:xmlel, name, attrs, Enum.map(children, &from_simple_form/1)}

      {:error, reason} ->
        raise "Failed to parse XML: #{inspect(reason)}"
    end
  end

  defp from_simple_form({name, attrs, children}) do
    {:xmlel, name, attrs, Enum.map(children, &from_simple_form/1)}
  end

  defp from_simple_form({:cdata, content}), do: {:xmlcdata, content}
  defp from_simple_form(binary) when is_binary(binary), do: {:xmlcdata, binary}
end
