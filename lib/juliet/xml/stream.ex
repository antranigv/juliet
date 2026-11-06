defmodule Juliet.XML.Stream do
  @moduledoc """
  Streaming XML parser for XMPP socket data.

  Uses `Saxy.Partial` under the hood and emits the same messages that
  `fast_xml`'s stream parser emitted:

    * `{:xmlstreamstart, name, attrs}`
    * `{:xmlstreamelement, stanza}`
    * `{:xmlstreamend, name}`
    * `{:xmlstreamerror, reason}`

  The XMPP `<stream:stream>` root is never closed by the server, so the parser
  treats the first start element as the stream root and only emits completed
  top-level children as stanzas.
  """

  alias __MODULE__.Handler

  @doc """
  Creates a new stream parser that sends events to `owner`.
  """
  def new(owner) do
    case Saxy.Partial.new(Handler, %{owner: owner, stack: [], root: nil}) do
      {:ok, partial} -> partial
      {:error, reason} -> raise "Failed to create XML stream parser: #{inspect(reason)}"
    end
  end

  @doc """
  Feeds the next chunk of XML data into the parser.
  """
  def parse(partial, data) when is_binary(data) do
    case Saxy.Partial.parse(partial, data) do
      {:cont, partial} -> {:ok, partial}
      {:halt, _state} -> {:ok, partial}
      {:halt, _state, _rest} -> {:ok, partial}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Resets the parser, e.g. after STARTTLS or SASL success.
  """
  def reset(partial) do
    state = Saxy.Partial.get_state(partial)
    new(state.owner)
  end
end

defmodule Juliet.XML.Stream.Handler do
  @moduledoc false
  @behaviour Saxy.Handler

  @impl Saxy.Handler
  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:start_element, {name, attrs}, %{stack: [], root: nil} = state) do
    send(state.owner, {:xmlstreamstart, name, attrs})
    {:ok, %{state | root: name}}
  end

  def handle_event(:start_element, {name, attrs}, %{stack: stack} = state) do
    {:ok, %{state | stack: [%{name: name, attrs: attrs, children: []} | stack]}}
  end

  def handle_event(:end_element, name, %{stack: [], root: name} = state) do
    send(state.owner, {:xmlstreamend, name})
    {:ok, state}
  end

  def handle_event(
        :end_element,
        name,
        %{stack: [%{name: name, attrs: attrs, children: children} | rest]} = state
      ) do
    element = {:xmlel, name, attrs, Enum.reverse(children)}

    case rest do
      [] ->
        send(state.owner, {:xmlstreamelement, element})
        {:ok, %{state | stack: []}}

      [%{name: parent_name, attrs: parent_attrs, children: parent_children} | tail] ->
        parent = %{name: parent_name, attrs: parent_attrs, children: [element | parent_children]}
        {:ok, %{state | stack: [parent | tail]}}
    end
  end

  def handle_event(:characters, _chars, %{stack: []} = state) do
    # Whitespace/characters at the stream root level are ignored. XMPP uses
    # whitespace as a keepalive; it is not a stanza.
    {:ok, state}
  end

  def handle_event(:characters, chars, %{stack: [%{children: children} = current | rest]} = state) do
    {:ok, %{state | stack: [%{current | children: [{:xmlcdata, chars} | children]} | rest]}}
  end

  def handle_event(:cdata, _chars, %{stack: []} = state) do
    {:ok, state}
  end

  def handle_event(:cdata, chars, %{stack: [%{children: children} = current | rest]} = state) do
    {:ok, %{state | stack: [%{current | children: [{:xmlcdata, chars} | children]} | rest]}}
  end

  def handle_event(:end_document, _data, state) do
    {:ok, state}
  end
end
