defmodule Juliet.MUC do
  @moduledoc """
  Convenience functions for joining and sending messages to Multi-User Chat
  (MUC) rooms.
  """

  alias Juliet.Connection
  alias Juliet.JID
  alias Juliet.Stanza

  import Juliet.XML, only: [attr: 2, subelement: 2]

  @default_timeout 5_000

  @doc """
  Joins a MUC room as `nick`.

  ## Options

  See `Juliet.Stanza.join/3` for supported options such as `:password` and
  `:history`.
  """
  def join(pid, room_jid, nick, opts \\ []) do
    Connection.send(pid, Stanza.join(room_jid, nick, opts))
  end

  @doc """
  Sends a groupchat message to `room_jid`, waiting for the self-presence
  confirmation (status 110) before sending.

  Returns `{:error, :timeout}` if the self-presence is not received within
  `timeout` milliseconds.

  ## Options

    * `:timeout` - milliseconds to wait for self-presence (default: 5000)
  """
  def send(pid, room_jid, body, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    case wait_for_self_presence(room_jid, timeout) do
      :ok -> Connection.send(pid, Stanza.groupchat(room_jid, body))
      error -> error
    end
  end

  defp wait_for_self_presence(room_jid, timeout) do
    room_bare = JID.bare(room_jid)

    receive do
      {:stanza, %Juliet.Stanza.Presence{from: from, xml: xml}} ->
        if JID.bare(from) == room_bare and self_presence?(xml) do
          :ok
        else
          send(self(), {:stanza, %Juliet.Stanza.Presence{from: from, xml: xml}})
          wait_for_self_presence(room_jid, timeout)
        end
    after
      timeout -> {:error, :timeout}
    end
  end

  defp self_presence?(xml) do
    case subelement(xml, "x") do
      nil ->
        false

      x ->
        attr(x, "xmlns") == Juliet.XMLNS.ns_muc_user() and
          x
          |> Juliet.XML.subelements("status")
          |> Enum.any?(fn status -> attr(status, "code") == "110" end)
    end
  end
end
