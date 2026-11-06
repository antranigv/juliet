# Juliet — Fork & Modernization Plan

Juliet is a fork of Romeo (scrogson/romeo, MIT, (c) Sonny Scroggin) — an XMPP client library for Elixir — maintained by Antranig Vartanian. Goal: pure Elixir (no C/NIFs), modern Elixir/OTP, same public API so Romeo users switch by renaming `Romeo` -> `Juliet`. Primary use case: connect, join a MUC, send a groupchat message, close.

## 0. Rules for the coding agent

- Work milestone by milestone, in order. Each milestone ends with `mix format`, `mix compile --warnings-as-errors`, `mix test` all green, then ONE local commit `M<n>: <title>`. **Never push, never add remotes, never open PRs/issues.**
- Keep public function names, arities, struct fields, and owner-process messages (`{:resource_bound, resource}`, `:connection_ready`, `{:stanza, stanza}`) identical to Romeo unless a milestone says otherwise.
- No mock XMPP server. Tests are unit tests plus recorded XML fixtures under `test/fixtures/`.
- Never hardcode JIDs, passwords, hosts. Live tests read env vars.
- Pure Elixir hex deps only. Record deviations in `DEVIATIONS.md`.
- Box has Elixir 1.18 / OTP 27; target `elixir: "~> 1.17"`.

## M1 — Rename Romeo -> Juliet
- Rename every module `Romeo.*` -> `Juliet.*`, files `lib/romeo/**` -> `lib/juliet/**`, tests likewise.
- `mix.exs`: `app: :juliet`, package name `juliet`, source_url `https://github.com/antranigv/juliet`, version `0.1.0`.
- Config keys `:romeo` -> `:juliet`.
- Keep LICENSE (MIT) and original copyright; append "Copyright (c) 2026 Antranig Vartanian" line and a fork note in README.
- If fast_xml blocks compilation here, it is acceptable to merge M1 and M2 into consecutive commits but M1 commit must be the rename only (tests may be marked pending with a note if they cannot compile until M2; document in DEVIATIONS.md).

## M2 — Remove C/NIF deps (fast_xml -> saxy)
- Drop `fast_xml` (and any other NIF dep) from mix.exs/mix.lock. Add `saxy`.
- Define `Juliet.XML.Element` (or keep Romeo's `xmlel`/record shape if public; preserve whatever type `Stanza` builders return as seen by users) with name, attrs, children; plus `{:xmlcdata, binary}`-equivalent text nodes.
- `Juliet.XML.encode/1`, attribute/child helpers (`attr/2`, `subelement/2`, `cdata/1`) matching Romeo.XML function names.
- Streaming parser: a saxy partial parser (`Saxy.Partial`) fed by TCP/TLS chunks; it must handle the never-closed `<stream:stream>` root, emitting `{:xmlstreamstart, name, attrs}`, each complete top-level child element as a stanza, and `:xmlstreamend`. Handle chunk boundaries mid-element and multiple stanzas per chunk. Restart parser after STARTTLS and SASL success.
- Tests: parse fixtures (stream header, features, success, message, presence, split chunks, unicode/Armenian text), encode round-trips, all `Juliet.Stanza` builders.

## M3 — Modernize
- `elixir: "~> 1.17"`, `extra_applications: [:logger, :ssl, :crypto, :public_key]`, update deps, fix all deprecations (Logger.warn, Bitwise, `use Mix.Config` -> `import Config`, etc.).
- TLS (STARTTLS and direct): `verify: :verify_peer`, `cacerts: :public_key.cacerts_get()`, `server_name_indication` = host charlist, `customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]`. Option `ssl_opts`/`verify: false` (or `insecure: true`) to disable verification.
- Replace the `connection` dep with `:gen_statem` only if straightforward; otherwise keep and note in DEVIATIONS.md.

## M4 — SCRAM auth
- Implement SCRAM-SHA-256 and SCRAM-SHA-1 (RFC 5802/7677) with `:crypto` (pbkdf2_hmac, mac, hash). Mechanism choice: prefer SHA-256, then SHA-1, fallback PLAIN; option to force mechanism. Verify server signature.
- Tests: RFC 5802 SHA-1 and RFC 7677 SHA-256 test vectors; mechanism selection from features fixtures.

## M5 — MUC send (primary feature)
- Reliable flow: connect -> STARTTLS -> auth -> bind -> session (if advertised) -> `:connection_ready`.
- Convenience: `Juliet.MUC.join(pid, room_jid, nick, opts)` and `Juliet.MUC.send(pid, room_jid, body)` built on existing `Stanza.join/2` and `Stanza.groupchat/2`; wait for self-presence (status 110) with timeout before sending. Keep Romeo functions untouched.
- `mix juliet.send_muc "message"` task and `examples/send_muc.exs`, reading `JULIET_JID`, `JULIET_PASSWORD`, `JULIET_ROOM`, `JULIET_NICK`, optional `JULIET_HOST`/`JULIET_PORT`/`JULIET_INSECURE`.
- Live test `test/live/muc_test.exs` tagged `:live`, excluded by default in `test_helper.exs`; skips if env vars missing. Run with `mix test --only live`.
- Unit tests for JID parsing and the task's arg/env handling.

## M6 — Docs
- README: what/why, install, quick start (send to MUC), TLS options, auth, fork note and credits to Romeo.
- CHANGELOG: 0.1.0 entry listing rename, saxy, TLS verify, SCRAM, MUC helpers.
- `MIGRATING.md`: Romeo -> Juliet (rename modules/app, config key, behavior differences e.g. TLS verification now on by default).
