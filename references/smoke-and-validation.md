# Smoke Testing and Coverage Targets

Use this file alongside the per-minor validation checklist in
`upgrade-playbook.md`. Run the smoke script and review the coverage table after
every minor-version hop, not only after the final target is reached.

---

## Smoke Script

Save as `bin/upgrade-smoke` (or run inline) and execute after each version hop:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Ruby:    $(ruby -v)"
echo "Bundler: $(bundle -v)"
echo "Rails:   $(bin/rails runner 'puts Rails.version')"

echo "--- db:prepare ---"
bin/rails db:prepare

echo "--- zeitwerk:check ---"
bin/rails zeitwerk:check

echo "--- assets:precompile ---"
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile

echo "--- tests ---"
if [ -d test ]; then
  bin/rails test
fi

if [ -d spec ]; then
  bundle exec rspec
fi

echo "--- brakeman ---"
bundle exec brakeman -q -w2 || true

echo "--- done ---"
```

This covers the minimum useful gates: database bootstrap, autoload/eager-load
validation, production asset compilation, test suite, and security scan.
Rails 7.2 made Brakeman and CI first-class defaults for new apps; treat them
as upgrade gates for existing apps too.

---

## Test Coverage Targets

Rails does not prescribe a numeric threshold. Official guidance says "good test
coverage"; FastRuby.io recommends at least 80% before starting an upgrade.
The table below is a practical heuristic, not an official Rails requirement.

| Coverage area | Minimum target | Preferred target | Why it matters during an upgrade |
|---|---|---|---|
| Boot / eager-load / autoloading smoke | 100% of CI environments | 100% plus `zeitwerk:check` on every PR | Catches naming, inflection, initialization, and load-path regressions early |
| Critical request / API flows | 100% of revenue- and auth-critical endpoints | 100% plus unhappy-path auth/authorization checks | Action Pack, params, exceptions, cookies, and routing changes show up here first |
| Model / query / callback behavior | 80% of touched models | 90%+ of models with enums, callbacks, encryption, STI, or custom SQL | Active Record and Active Support changes often break these seams |
| Background jobs / mailers | 100% of jobs with side effects | 100% plus adapter-specific integration checks | Rails 7.2 and 8.0 changed job semantics enough that thin tests are risky |
| System tests for browser flows | At least one happy-path test per critical user journey | Happy path + one auth/error path per critical journey | Catches sessions, redirects, JS imports, assets, and unsupported driver issues |
| Channels / broadcasts | 100% of channel authorization and broadcast flows if Action Cable is used | Same, plus multi-process staging verification | Action Cable issues often only appear under real concurrency |
| Assets / build pipeline | One production precompile smoke per build variant | Per-PR production precompile plus one rendered-page smoke | Asset-stack upgrades fail late unless precompile is tested early |
| Database bootstrap / schema | `db:prepare` on every PR | `db:prepare` plus periodic fresh-DB replay job | Rails 8 changed fresh-DB migration behavior; schema loading must be verified |
