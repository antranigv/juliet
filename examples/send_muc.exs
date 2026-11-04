# Usage:
#
#   JULIET_JID=juliet@capulet.lit \
#   JULIET_PASSWORD=secret \
#   JULIET_ROOM=library@muc.capulet.lit \
#   JULIET_NICK=juliet \
#   mix run examples/send_muc.exs "Hello, MUC!"

alias Juliet.Connection
alias Juliet.MUC

message =
  case System.argv() do
    [msg | _] -> msg
    [] -> raise "expected a message argument"
  end

opts = [
  jid: System.fetch_env!("JULIET_JID"),
  password: System.fetch_env!("JULIET_PASSWORD")
]

opts =
  case System.get_env("JULIET_HOST") do
    nil -> opts
    host -> [{:host, host} | opts]
  end

opts =
  case System.get_env("JULIET_PORT") do
    nil -> opts
    port -> [{:port, String.to_integer(port)} | opts]
  end

opts =
  if System.get_env("JULIET_INSECURE") in ["1", "true"] do
    [{:ssl_opts, [verify: :verify_none]} | opts]
  else
    opts
  end

room = System.fetch_env!("JULIET_ROOM")
nick = System.fetch_env!("JULIET_NICK")

{:ok, pid} = Connection.start_link(opts)

receive do
  :connection_ready -> :ok
after
  15_000 -> raise "timed out waiting for connection_ready"
end

:ok = MUC.join(pid, room, nick)
:ok = MUC.send(pid, room, message)

:ok = Connection.close(pid)
