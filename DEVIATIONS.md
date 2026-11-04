# Deviations from plan.md

## M1 and M2 were merged

The instruction was to implement **only milestone M1**. However, after renaming
`Romeo` to `Juliet`, compilation failed because `:fast_xml` is a C/NIF
dependency and the build environment lacks `expat.h` (libexpat1-dev is not
installed and the system package repositories are unreachable).

plan.md anticipates exactly this situation:

> If fast_xml blocks compilation here, it is acceptable to merge M1 and M2 into
> consecutive commits but M1 commit must be the rename only (tests may be marked
> pending with a note if they cannot compile until M2; document in
> DEVIATIONS.md).

To satisfy `mix compile --warnings-as-errors` and `mix test`, the M2 work was
performed immediately after the rename:

* `:fast_xml` and `:ejabberd` were removed from `mix.exs`.
* `:saxy` was added as the pure-Elixir XML library.
* `Juliet.XML` and `Juliet.XML.Stream` were implemented to replace `:fxml` and
  `:fxml_stream`.
* `Juliet.Transports.TCP` was updated to use the new Saxy-based stream parser.
* The test suite was converted from ejabberd-backed integration tests to unit
  tests plus XML fixtures under `test/fixtures/`.

## XML representation

plan.md says to define `Juliet.XML.Element` with `name`, `attrs`, and
`children`. Instead, the public tuple shape that Romeo exposed via `fast_xml`
was preserved:

* `{:xmlel, name, attrs, children}`
* `{:xmlcdata, content}`
* `{:xmlstreamstart, name, attrs}`
* `{:xmlstreamend, name}`

This minimizes API churn for existing Romeo users while still satisfying the
"preserve whatever type `Stanza` builders return as seen by users" requirement.

## Config keys

The original project had no `:romeo` config keys in `config/config.exs`. The
`:ejabberd` config block was removed as part of dropping the `:ejabberd` test
dependency.

## Tests

The previous `test/user_helper.exs` and the ejabberd-backed live tests in
`test/juliet/connection_test.exs` and `test/juliet/roster_test.exs` were
replaced with unit tests that exercise the renamed modules and the new
Saxy-based XML layer.

## M2 verification

Milestone M2 was verified as complete. The only deviation from `plan.md` is the
preservation of the public `{:xmlel, ...}` tuple shape documented above. A
duplicate `Juliet.Stanza.to_xml/1` clause was removed, an XML parse/encode
round-trip test was added, and leftover unused NIF dependency directories were
cleaned with `mix deps.clean --unused`.

## M4 — SCRAM authentication

### Mechanism selection is public for testability

`Juliet.Auth.preferred_mechanism/2` was changed from a private function to a
public (but undocumented, `@doc false`) function. This keeps the mechanism
selection tests simple and avoids the need for a full mock transport exchange
just to verify that SCRAM-SHA-256 is preferred over SCRAM-SHA-1 and PLAIN. All
other public function names, arities, struct fields, and owner-process messages
remain identical to Romeo.

### Whitespace in `<mechanisms>` children

While implementing the mechanism-selection tests, `Juliet.Connection.Features`
was fixed to ignore non-`xmlel` whitespace children when parsing the list of
advertised SASL mechanisms. This is a bug fix in the existing feature parser,
not a behavior change.

### Implementation notes

* SCRAM-SHA-1 and SCRAM-SHA-256 are implemented in `Juliet.Auth.SCRAM` using
  `:crypto.pbkdf2_hmac/5`, `:crypto.mac/4`, and `:crypto.hash/2`.
* The default preference order is SCRAM-SHA-256 → SCRAM-SHA-1 → PLAIN.
* Users can force a mechanism by setting `preferred_auth_mechanisms:` to a list
  containing only that mechanism (e.g., `["SCRAM-SHA-1"]`).
* Server signatures are verified against the expected value derived during the
  exchange.

## M5 — MUC send

### `Juliet.MUC.send/4` accepts an optional `:timeout`

`plan.md` specifies `Juliet.MUC.send(pid, room_jid, body)`. The implemented
function has an optional fourth argument for options, currently used to
override the self-presence wait timeout (default 5000 ms). Calling it as
`Juliet.MUC.send(pid, room_jid, body)` remains the normal usage.

### Mix task parsing helpers are public for testing

`Mix.Tasks.Juliet.SendMuc.parse_args/1` and
`Mix.Tasks.Juliet.SendMuc.config_from_env/0` are public but marked `@doc false`
so that the task's argument and environment-variable handling can be unit
tested without making a real network connection.

### Live MUC test skip decision is made at compile time

`ExUnit.SkipError` is not available in the Elixir/ExUnit version installed in
this environment, so the live test determines at compile time whether the
required `JULIET_*` environment variables are present and sets `@tag skip:`
accordingly. If the variables are missing, `mix test --only live` reports the
test as skipped.
