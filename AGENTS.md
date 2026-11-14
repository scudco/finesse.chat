# AGENTS.md

Rails 8 app demoing Polling, WebSockets, and SSE. Overview and dev setup: [README.md](README.md).
Shipping standard, definition of ready, feature flags: [docs/SHIPPING.md](docs/SHIPPING.md).

## Gate

Run the full `bin/ci` before every PR; it must pass. Steps live in `config/ci.rb`; a run takes ~35s.

- Its first step, `bin/setup --skip-server`, may `bundle install`, runs `db:prepare`, and
  clears `log/` and `tmp/` (including system-test screenshots and `tmp/finesse_test.log`).
  Copy anything you need from there before rerunning.
- System tests drive headless Chrome; it works on agent machines.
- GitHub CI (`.github/workflows/ci.yml`) also builds and boots the production Docker image
  (`deploy-validation` job). Docker is unavailable on agent machines, so `Dockerfile` and
  boot problems surface only in GitHub CI, not in `bin/ci`.

## Production

Merging to `main` deploys to production: CI success on `main` triggers
`.github/workflows/deploy.yml`, which runs `bin/kamal deploy`.

- Leave deploys to humans: never run `bin/kamal` deploy/rollback commands or the deploy workflow.
- Never read or write production data or servers.
- Ship unfinished work behind a feature flag (see docs/SHIPPING.md) so merging stays safe.
