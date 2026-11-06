defmodule Mix.Tasks.Juliet.SendMuc do
  use Mix.Task

  @shortdoc "Sends a message to a MUC room"

  @moduledoc """
  Connects to an XMPP server, joins a MUC room, sends a message, and disconnects.

  Required environment variables:

    * JULIET_JID
    * JULIET_PASSWORD
    * JULIET_ROOM
    * JULIET_NICK

  Optional environment variables:

    * JULIET_HOST
    * JULIET_PORT
    * JULIET_INSECURE - set to "1" or "true" to disable TLS verification

  Usage:

      mix juliet.send_muc "Hello, MUC!"
  """

  alias Juliet.Connection
  alias Juliet.MUC

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start", [])

    message = parse_args(args)
    opts = config_from_env()

    {:ok, pid} = Connection.start_link(opts)
    assert_ready!()

    :ok = MUC.join(pid, opts[:room], opts[:nick])
    :ok = MUC.send(pid, opts[:room], message)

    :ok = Connection.close(pid)
  end

  @doc false
  def parse_args([message | _]) when is_binary(message), do: message
  def parse_args([]), do: raise(Mix.Error, message: "expected a message argument")

  @doc false
  def config_from_env do
    jid = System.fetch_env!("JULIET_JID")
    password = System.fetch_env!("JULIET_PASSWORD")
    room = System.fetch_env!("JULIET_ROOM")
    nick = System.fetch_env!("JULIET_NICK")

    opts = [
      jid: jid,
      password: password,
      room: room,
      nick: nick
    ]

    opts = if host = System.get_env("JULIET_HOST"), do: [{:host, host} | opts], else: opts

    opts =
      if port = System.get_env("JULIET_PORT"),
        do: [{:port, String.to_integer(port)} | opts],
        else: opts

    if insecure?(System.get_env("JULIET_INSECURE")) do
      [{:ssl_opts, [verify: :verify_none]} | opts]
    else
      opts
    end
  end

  defp insecure?(nil), do: false
  defp insecure?("1"), do: true
  defp insecure?("true"), do: true
  defp insecure?(_), do: false

  defp assert_ready! do
    receive do
      :connection_ready -> :ok
    after
      15_000 -> raise "timed out waiting for connection_ready"
    end
  end
end
