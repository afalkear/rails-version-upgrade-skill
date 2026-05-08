# Universal Rails Upgrade Playbook

This document covers every step of a Rails version upgrade in execution order.
The same steps apply regardless of whether you are moving from 6.1→7.0 or
7.2→8.0. Repeat the full cycle for each minor-version hop.

---

## Phase 0 — Pre-Upgrade Assessment

### 0.1 Determine the upgrade path

```
current → next_minor → … → target
```

Examples:
- 6.0 → 6.1 → 7.0 → 7.1 → 7.2 → 8.0
- 7.2 → 8.0
- 7.0 → 7.1 (single hop)

Never jump across minor versions. Each hop is a complete cycle.

### 0.2 Verify test coverage

```bash
bundle exec rake stats
```

Run the full test suite and confirm it is green:

```bash
bundle exec rails test        # Minitest
bundle exec rspec             # RSpec
```

If coverage is below ~80%, strongly recommend adding tests before proceeding.
Use `simplecov` if not already configured.

### 0.3 Upgrade to the latest patch of the current version first

```ruby
# Gemfile — pin to the latest patch, not the next minor
gem 'rails', '~> 7.2.0'   # example
```

```bash
bundle update rails
bundle exec rails test
```

This surfaces deprecation warnings that are *already* in the codebase and ensures
you start from the most recent stable point.

### 0.4 Check Ruby version requirements

Consult the compatibility table:
https://www.fastruby.io/blog/ruby/rails/versions/compatibility-table.html

| Rails | Min Ruby |
|-------|----------|
| 8.0, 8.1 | 3.2.0+ |
| 7.2 | 3.1.0+ |
| 7.0, 7.1 | 2.7.0+ |
| 6.x | 2.5.0+ |

If the current Ruby is below the minimum for the target Rails, upgrade Ruby
**first** (in its own PR/branch), then proceed with the Rails upgrade.

### 0.5 Inventory application surfaces

Before touching any gem versions, run an application inventory to surface the
exact places where version changes commonly cause breakage:

```bash
bin/rails about
bin/rails initializers
bin/rails middleware
bin/rails routes --expanded
bundle outdated || true
```

Then grep for known high-risk patterns across your codebase:

```bash
git grep -nE 'Rails\.application\.secrets|read_encrypted_secrets|config\.autoloader|ActiveSupport::Dependencies|require_dependency|@rails/ujs|webpacker|poltergeist|capybara-webkit|alias_attribute|enqueue_after_transaction_commit|BroadcastLogger|\.broadcast\(' \
  -- '*.rb' '*.erb' '*.js'
```

Also verify your autoload path layout before crossing a major boundary:

```bash
bin/rails runner 'pp Rails.autoloaders.main.dirs; pp Rails.autoloaders.once.dirs'
```

### 0.6 Scan for gem incompatibilities

```bash
gem install next_rails
next --init   # or: bundle exec next --init
bundle exec next_rails bundle_report
```

Alternatively, paste `Gemfile.lock` into https://railsbump.org/ and filter for
the target Rails version. Create a list of gems that need updating.

---

## Phase 1 — Fix Deprecations in the Current Version

### 1.1 Collect all deprecation warnings

```bash
RAILS_LOG_LEVEL=warn bundle exec rails test 2>&1 | grep DEPRECATION
```

For targeted CI enforcement, configure `disallowed_deprecation_warnings` in
`config/environments/test.rb` to fail the build only on deprecations you have
already decided to eliminate — while still logging others:

```ruby
# config/environments/test.rb
Rails.application.configure do
  config.active_support.deprecation = :stderr
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = [
    /Rails\.application\.secrets/,
    /config\.autoloader=/,
    /ActiveSupport::Dependencies/,
    /enqueue_after_transaction_commit/,
    /require_dependency/
  ]
end
```

Extend the array as you identify and commit to eliminating each warning.

### 1.2 Fix every deprecation

Each deprecation warning is a documented breaking change in the next version.
Work through them systematically. See `references/version-specific-notes.md`
for the exact changes by version.

### 1.3 Verify the suite is still green

```bash
bundle exec rails test    # or rspec
```

---

## Phase 2 — Align `config.load_defaults`

Before bumping the Rails version, make sure `config.load_defaults` in
`config/application.rb` matches the **current** version.

See `references/framework-defaults.md` for the full workflow.

---

## Phase 3 — Set Up Dual Boot

Dual booting lets you switch between the current and target Rails version with
a single environment variable. This is the most powerful debugging technique
during an upgrade.

### 3.1 Install `next_rails`

```bash
gem install next_rails
next --init
```

This creates `Gemfile.next` and a helper method `NextRails.next?`.

**Alternative: `eval_gemfile` pattern (no helper gem needed)**

If you prefer not to use `next_rails`, create `Gemfile.next` manually using
`eval_gemfile` to inherit the base Gemfile and only override the Rails pin:

```ruby
# Gemfile.next
eval_gemfile "Gemfile"

gem "rails", "~> 8.0.0"
# Add temporary compatibility pins here only if needed.
```

This approach is simpler for apps where the base Gemfile does not need
conditional branches — just point `BUNDLE_GEMFILE=Gemfile.next` at it.

### 3.2 Edit Gemfile to conditionally pin Rails version (next_rails path)

If using `next_rails`, add a version conditional to the base Gemfile:

```ruby
# Gemfile
if NextRails.next?
  gem 'rails', '~> 8.0'
else
  gem 'rails', '~> 7.2'
end
```

### 3.3 Install dependencies for both variants

```bash
bundle install                              # current version
BUNDLE_GEMFILE=Gemfile.next bundle install  # target version
```

### 3.4 Configure CI to test both

Add a parallel CI job matrix. The example below targets GitHub Actions with
PostgreSQL; adapt the `services` block and `DATABASE_URL` for MySQL or SQLite.

```yaml
name: rails-upgrade

on:
  pull_request:
  push:
    branches: [main]

jobs:
  upgrade-matrix:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        ruby: ["3.2", "3.3"]
        gemfile: ["Gemfile", "Gemfile.next"]

    env:
      RAILS_ENV: test
      BUNDLE_GEMFILE: ${{ matrix.gemfile }}
      DATABASE_URL: postgres://postgres:postgres@127.0.0.1:5432/app_test

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: app_test
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports: ["5432:5432"]
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby }}
          bundler-cache: true

      - uses: actions/setup-node@v4
        if: ${{ hashFiles('package.json') != '' }}
        with:
          node-version: 22

      - name: Database setup
        run: bin/rails db:prepare

      - name: Zeitwerk check
        run: bin/rails zeitwerk:check

      - name: Minitest
        if: ${{ hashFiles('test/**/*') != '' }}
        run: bin/rails test

      - name: RSpec
        if: ${{ hashFiles('spec/**/*') != '' }}
        run: bundle exec rspec

      - name: Assets precompile
        run: RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile

      - name: Brakeman
        run: bundle exec brakeman -q -w2
```

Both `Gemfile` and `Gemfile.next` jobs must be green before the upgrade is
considered complete.

### 3.5 How to use dual boot for debugging

```bash
# Run with current Rails
bundle exec rails test spec/models

# Run with target Rails
BUNDLE_GEMFILE=Gemfile.next bundle exec rails test spec/models
```

Adding a debugger (`binding.pry` / `debugger`) and switching between the two
commands is the most efficient way to understand behavioral changes between
versions.

---

## Phase 4 — Bump Rails in `Gemfile.next`

### 4.1 Update the target Rails constraint

```ruby
# Gemfile — target side of the conditional
gem 'rails', '~> 8.0'
```

```bash
BUNDLE_GEMFILE=Gemfile.next bundle update rails
```

### 4.2 Verify the app boots

```bash
BUNDLE_GEMFILE=Gemfile.next bundle exec rails runner "puts Rails.version"
```

If the app fails to boot, fix boot errors before running tests.

---

## Phase 5 — Run `bin/rails app:update`

```bash
BUNDLE_GEMFILE=Gemfile.next bundle exec rails app:update
```

This command:
- Regenerates or updates standard config files (`config/application.rb`,
  `config/environments/*.rb`, `config/routes.rb`, boot files, etc.)
- Creates `config/initializers/new_framework_defaults_X_Y.rb` with all new
  defaults commented out

**Review every diff carefully.** Use `THOR_DIFF` to get a colored inline diff
rather than the default interactive prompt:

```bash
THOR_DIFF="git diff --no-index --color" \
  BUNDLE_GEMFILE=Gemfile.next bundle exec rails app:update
```

Do not blindly accept all changes. Common safe accepts:
- New initializer files
- Minor `routes.rb` boilerplate changes

Common changes to review manually:
- `config/application.rb` — may overwrite custom settings
- `config/environments/production.rb` — security/caching defaults may change
- `config/database.yml` — new adapter options may appear

If your app uses JavaScript bundling via `jsbundling-rails`, also align the
Rails JavaScript packages after the version bump:

```bash
BUNDLE_GEMFILE=Gemfile.next bundle exec rails javascript:install
```

Commit the result of `app:update` in its own commit before making further
changes.

---

## Phase 6 — Resolve Gem Incompatibilities

See `references/gem-compatibility.md` for detailed guidance.

The short version:
1. Run `BUNDLE_GEMFILE=Gemfile.next bundle install` and note every conflict.
2. Update gems one at a time: `BUNDLE_GEMFILE=Gemfile.next bundle update <gem>`.
3. Run the test suite after each gem update.
4. Use `NextRails.next?` conditionals for gems that have incompatible APIs
   between the old and new Rails versions.

---

## Phase 7 — Fix the Broken Build

After the version bump, the test suite against `Gemfile.next` will likely be
red. See `references/broken-build-triage.md` for the systematic approach.

High-level order of operations:
1. Fix load errors / boot failures first (nothing else can run).
2. Fix errors (exceptions) before failures (assertion mismatches).
3. Start with model tests (most isolated).
4. Group failures by root cause; fix in batches.
5. Cross-reference `references/version-specific-notes.md` for known breaking
   changes in the target version.

---

## Phase 8 — Migrate Framework Defaults

Work through `config/initializers/new_framework_defaults_X_Y.rb` one default
at a time.

See `references/framework-defaults.md` for the full workflow.

---

## Phase 9 — Promote

When both `Gemfile` and `Gemfile.next` produce a passing suite:

1. Update `Gemfile` to the new Rails version (drop the conditional):

```ruby
gem 'rails', '~> 8.0'
```

2. Update `config.load_defaults` in `config/application.rb`:

```ruby
config.load_defaults 8.0
```

3. Delete `Gemfile.next` and `Gemfile.next.lock`.

4. Remove all `NextRails.next?` / `if Rails::VERSION >= ...` conditionals
   introduced during the upgrade.

5. Delete `config/initializers/new_framework_defaults_X_Y.rb` (all defaults
   are now active via `config.load_defaults`).

6. Run the full suite one final time. It must be green.

```bash
bundle exec rails test
```

---

## Per-Minor Validation Checklist

Run this checklist **after every minor-version hop** (not only at the end).
See `references/smoke-and-validation.md` for the smoke script and coverage
targets.

- [ ] App boots in development, test, and production-like configuration.
- [ ] `bin/rails db:prepare` succeeds on a fresh checkout.
- [ ] `bin/rails zeitwerk:check` passes.
- [ ] Full automated test suite passes; if both `test/` and `spec/` exist,
      both runners are exercised.
- [ ] Production asset precompile passes (`SECRET_KEY_BASE_DUMMY=1`).
      If the asset stack changed, at least one rendered page is smoke-tested.
- [ ] Authentication, session continuity, password reset, and signed/encrypted
      values are manually verified.
- [ ] At least one job enqueued from transactional code is verified end-to-end.
- [ ] If Action Cable is used, a broadcast is tested across more than one
      process.
- [ ] File upload, download, image variants, and previews are verified if
      Active Storage is used.
- [ ] No critical deprecations remain in test/staging logs.
- [ ] `config.load_defaults` has **not** been flipped until the framework-only
      upgrade is stable.
- [ ] Canary deploy succeeds before broad rollout.
- [ ] Temporary compatibility shims are tracked and scheduled for removal after
      stabilization.

---

## Phase 10 — Repeat for the Next Hop

If the target version is more than one minor hop away, go back to Phase 0
with the promoted version as the new current version.
