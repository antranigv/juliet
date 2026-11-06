# Juliet

> An XMPP client for Elixir

Juliet is a fork of [Romeo](https://github.com/scrogson/romeo) (MIT, © Sonny
Scroggin), maintained by Antranig Vartanian. It provides the same public API as
Romeo — in most cases renaming `Romeo` to `Juliet` is enough to switch — but it
is implemented in pure Elixir with no C/NIF dependencies and targets modern
Elixir/OTP.

The primary use case is connecting to an XMPP server, joining a Multi-User Chat
(MUC) room, sending a message, and disconnecting cleanly.

## Installation

Add `:juliet` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:juliet, "~> 0.1"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick start: send a message to a MUC room

```elixir
alias Juliet.Connection
alias Juliet.MUC

opts = [
  jid: "juliet@capulet.lit",
  password: "iL0v3JuL137"
]

{:ok, pid} = Connection.start_link(opts)

receive do
  :connection_ready -> :ok
after
  15_000 -> raise "timed out waiting for connection_ready"
end

:ok = MUC.join(pid, "library@muc.capulet.lit", "juliet")
:ok = MUC.send(pid, "library@muc.capulet.lit", "Hello, MUC!")

:ok = Connection.close(pid)
```

The connection flow is: open the XMPP stream, negotiate STARTTLS when offered,
authenticate, bind a resource, optionally establish a session, and then send
`:connection_ready` to the owner process.

A ready-to-run example is available at `examples/send_muc.exs`, and a Mix task
is provided as `mix juliet.send_muc "Hello, MUC!"`.

## TLS options

By default Juliet verifies the peer certificate using the host's CA trust
store, sets `server_name_indication` to the target host, and enables
`verify_peer`. This is the recommended configuration for production.

To disable certificate verification (for example against a test server with a
self-signed certificate), pass `ssl_opts: [verify: :verify_none]`:

```elixir
opts = [
  jid: "juliet@capulet.lit",
  password: "iL0v3JuL137",
  ssl_opts: [verify: :verify_none]
]
```

You can also pass any other `:ssl` options through `ssl_opts`.

## Authentication

Juliet negotiates SASL authentication automatically. The default preference
order is:

1. `SCRAM-SHA-256`
2. `SCRAM-SHA-1`
3. `PLAIN`

To force a specific mechanism, set `preferred_auth_mechanisms`:

```elixir
opts = [
  jid: "juliet@capulet.lit",
  password: "iL0v3JuL137",
  preferred_auth_mechanisms: ["SCRAM-SHA-1"]
]
```

## Fork note and credits

Juliet is a fork of Romeo by Sonny Scroggin. Many thanks to the original
authors and contributors for the design and API that Juliet builds on.

## License

The MIT License (MIT)

Copyright (c) 2015 Sonny Scroggin
Copyright (c) 2026 Antranig Vartanian

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
