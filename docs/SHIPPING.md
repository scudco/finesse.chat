# Shipping standard

What must be true before a change ships, and how to prove it without a human
clicking around. Every layer runs in CI on each PR and push to main; a deploy
happens only after all of them pass.

## The validation ladder

| Layer | Command | Proves |
|-------|---------|--------|
| Static checks | `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit` | Style, known CVEs, static security |
| Unit + integration | `bin/rails test` | Models, controllers, jobs, feature flags, transport selection |
| System (e2e) | `bin/rails test:system` | Real Chrome against the running app: message flows, and live delivery through all three transports — WebSockets, polling, and SSE via the actual Finesse Go server |
| Deploy validation | CI `deploy-validation` job | The production Docker image builds, boots, migrates, and serves the homepage; `kamal config` still renders |
| Post-deploy smoke | `deploy` workflow, after `kamal deploy` | Production `/up`, the SSE host's `/up`, and the live homepage respond |

Run everything locally with `bin/ci`.

## Definition of ready

A change is ready to merge when:

1. `bin/ci` passes.
2. New user-visible behavior has a system test that exercises it in the
   browser, or a short note in the PR saying why it cannot.
3. Risky or unfinished work is behind a feature flag (below), so merging to
   main stays safe.

The suite is a standard, not a bureaucratic gate: a red system test means a
user-visible flow broke. Fix the flow or fix the test's assumption; never
skip it.

## Transport e2e notes

`test/system/transports_test.rb` covers the app's reason to exist. The SSE
test boots the real Finesse binary from the gem against the test cable
database. Two deviations from stock Rails testing make that work, documented
in the test file:

- `SseTransportTest` disables transactional tests (an external process cannot
  see uncommitted rows).
- It restores the real `solid_cable` pubsub adapter that `rails/test_help`
  silently replaces with an in-memory one.

If an SSE test fails, the error message carries browser-side and server-side
diagnostics (CSP/CORS reachability, process liveness, origin ACK). Finesse
output lands in `tmp/finesse_test.log`.

## Feature flags

`app/models/feature.rb` holds a minimal flag registry. Use it to merge and
deploy unfinished work dark, then test it live:

1. Register the flag default-off in `Feature::FLAGS` and branch on
   `Feature.enabled?(:my_flag, session)`.
2. Ship to main. CI and deploy run as usual; nobody sees the feature.
3. Verify it in production with `https://finesse.chat/?enable_feature=my_flag`
   (sets a session override for you alone; `?disable_feature=` undoes it).
4. Enable it for everyone with `FEATURE_MY_FLAG=enabled` in the `env` section
   of `config/deploy.yml`, or flip the default in code.
5. Delete the flag once the feature is proven. Flags are scaffolding, not
   architecture.

## Deploy pipeline

`main` → CI (all jobs above) → `deploy` workflow → `bin/kamal deploy` →
post-deploy smoke. Rollback is `bin/kamal rollback [version]` from a machine
with the deploy secrets, or revert the commit and let the pipeline redeploy.

Deliberately not built yet:

- **Staging host.** The CI `deploy-validation` job boots the production image
  as an ephemeral environment, which covers "will it deploy". When a second
  host exists, add a Kamal destination (`config/deploy.staging.yml`,
  `bin/kamal deploy -d staging`) and point a smoke job at it.
- **Automatic rollback on failed smoke.** The smoke step fails the workflow
  loudly; acting on it stays a human call.
