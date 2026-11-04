defmodule Juliet.Live.MUCTest do
  use ExUnit.Case, async: false

  @moduletag :live

  alias Juliet.Connection
  alias Juliet.MUC

  @required_env [
    "JULIET_JID",
    "JULIET_PASSWORD",
    "JULIET_ROOM",
    "JULIET_NICK"
  ]

  missing = Enum.reject(@required_env, &System.get_env/1)

  @tag skip:
         if(Enum.empty?(missing),
           do: false,
           else: "missing env vars: #{Enum.join(missing, ", ")}"
         )

  test "connects, joins a MUC room, and sends a message" do
    opts = [
      jid: System.fetch_env!("JULIET_JID"),
      password: System.fetch_env!("JULIET_PASSWORD")
    ]

    opts = maybe_add(:host, "JULIET_HOST", opts)
    opts = maybe_add_int(:port, "JULIET_PORT", opts)

    opts =
      if System.get_env("JULIET_INSECURE") in ["1", "true"] do
        [{:ssl_opts, [verify: :verify_none]} | opts]
      else
        opts
      end

    room = System.fetch_env!("JULIET_ROOM")
    nick = System.fetch_env!("JULIET_NICK")

    {:ok, pid} = Connection.start_link(opts)

    assert_receive :connection_ready, 15_000

    assert :ok = MUC.join(pid, room, nick)
    assert :ok = MUC.send(pid, room, "Hello from Juliet live test!")

    assert :ok = Connection.close(pid)
  end

  defp maybe_add(key, env, opts) do
    case System.get_env(env) do
      nil -> opts
      value -> [{key, value} | opts]
    end
  end

  defp maybe_add_int(key, env, opts) do
    case System.get_env(env) do
      nil -> opts
      value -> [{key, String.to_integer(value)} | opts]
    end
  end
end
