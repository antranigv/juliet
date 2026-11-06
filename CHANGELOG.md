# Changelog

## v0.1.0

- Fork from Romeo: renamed all modules, application, and config keys from
  `Romeo` to `Juliet`.
- Replaced the `fast_xml` C/NIF dependency with the pure-Elixir `saxy` XML
  parser.
- Enabled TLS peer verification by default using the host CA trust store,
  `server_name_indication`, and `:public_key` hostname checking.
- Added SCRAM-SHA-256 and SCRAM-SHA-1 authentication with `:crypto`, falling
  back to PLAIN when the server does not advertise SCRAM.
- Added `Juliet.MUC` helpers (`join/3` and `send/3`) for joining and sending
  messages to MUC rooms, including self-presence confirmation before sending.
- Added `mix juliet.send_muc` task and `examples/send_muc.exs` for the primary
  use case.

## v0.4.0

- Enhancements
  - [Romeo.Stanza.join/3] adds options for specifying MUC room password and
    history options.

## v0.3.0

- Backwards incompatible changes
  - Removed `payload` key in favor of `xml` in the `Message`, `Presence`, and
    `IQ` stanzas. The full `xmlel` record is now stored in the `xml` key. This
    allows easy access via the functions in `Romeo.XML` module.
  - Messages generated with `Romeo.Stanza.message/3` no longer escape the body
    by default.

## v0.2.0

- Enhancements
  - [Romeo.JID] Added `user/1` which returns the `user` portion of the JID.
  - [Romeo.JID] Added `server/1` which returns the `server` portion of the JID.
  - [Romeo.JID] Added `resource/1` which returns the `resource` portion of the JID.
  - [Romeo.JID] Added key `full` JID struct for convenient access to the full
    JID.
  - [Romeo.Stanza] Added a clause to `to_xml/1` for `%Romeo.Stanza.Message{}`.
  - [Romeo.XML] Added a clause to `encode!/1` to handle all stanza structs.

- Backward incompatible changes
  - [Romeo.Connection] No longer sends stanza messages to the owner process
    until after the connection process has finished.
  - [Romeo.Connection] Stanzas sent to the owner process are now parsed into the
    matching stanza struct. The message tuple has changed from
    `{:stanza_received, stanza}` to `{:stanza, stanza}`.

## v0.1.0

Initial release :tada:
