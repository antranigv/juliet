defmodule Juliet.MUC do
  @moduledoc """
  Convenience functions for joining and sending messages to Multi-User Chat
  (MUC) rooms.
  """

  alias Juliet.Connection
  alias Juliet.JID
  alias Juliet.Stanza

  import Juliet.XML, only: [attr: 2]

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
    deadline = System.monotonic_time(:millisecond) + timeout

    case wait_for_self_presence(room_jid, deadline, []) do
      :ok -> Connection.send(pid, Stanza.groupchat(room_jid, body))
      error -> error
    end
  end

  defp wait_for_self_presence(room_jid, deadline, deferred) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      restore(deferred)
      {:error, :timeout}
    else
      room_bare = JID.bare(room_jid)

      receive do
        {:stanza, %Juliet.Stanza.Presence{from: from, xml: xml}} = msg ->
          if JID.bare(from) == room_bare and self_presence?(xml) do
            restore(deferred)
            :ok
          else
            wait_for_self_presence(room_jid, deadline, [msg | deferred])
          end

        other ->
          wait_for_self_presence(room_jid, deadline, [other | deferred])
      after
        remaining ->
          restore(deferred)
          {:error, :timeout}
      end
    end
  end

  defp restore(deferred) do
    deferred
    |> Enum.reverse()
    |> Enum.each(&send(self(), &1))
  end

  defp self_presence?(xml) do
    xml
    |> Juliet.XML.subelements("x")
    |> Enum.any?(fn x ->
      attr(x, "xmlns") == Juliet.XMLNS.ns_muc_user() and
        x
        |> Juliet.XML.subelements("status")
        |> Enum.any?(fn status -> attr(status, "code") == "110" end)
    end)
  end
end
