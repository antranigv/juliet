# Migrating from Romeo to Juliet

Juliet is a drop-in fork of Romeo. In most cases you only need to rename
modules, the application, and any configuration keys.

## Module rename

Replace every `Romeo` module prefix with `Juliet`:

| Romeo | Juliet |
|-------|--------|
| `Romeo.Connection` | `Juliet.Connection` |
| `Romeo.Stanza` | `Juliet.Stanza` |
| `Romeo.JID` | `Juliet.JID` |
| `Romeo.Roster` | `Juliet.Roster` |
| `Romeo.XML` | `Juliet.XML` |
| `Romeo.MUC` | `Juliet.MUC` |

Aliases and `as:` references should be updated similarly.

## Application and dependency

In `mix.exs` change the dependency from `:romeo` to `:juliet`:

```elixir
def deps do
  [
    {:juliet, "~> 0.1"}
  ]
end
```

If you list applications explicitly, change `:romeo` to `:juliet`.

## Configuration keys

Any application config keyed under `:romeo` should move to `:juliet`:

```elixir
config :juliet,
  # your options
```

## Behavior differences

### TLS verification is enabled by default

Juliet enables `:verify_peer` and validates the server certificate against the
host CA trust store. If you connect to a server with a self-signed certificate
you must explicitly disable verification:

```elixir
opts = [
  jid: "juliet@capulet.lit",
  password: "secret",
  ssl_opts: [verify: :verify_none]
]
```

Romeo did not verify peer certificates by default.

### Authentication preference

Juliet prefers SCRAM-SHA-256, then SCRAM-SHA-1, and falls back to PLAIN. You
can force a specific mechanism with `preferred_auth_mechanisms`.

### XML representation

The public XML element shape remains the same tuple form that Romeo exposed
through `fast_xml` (`{:xmlel, name, attrs, children}` and
`{:xmlcdata, content}`). Code that pattern-matched on these tuples does not
need to change.

## New helpers

`Juliet.MUC` provides `join/3` and `send/3` helpers for the common
connect-join-send-disconnect flow.
