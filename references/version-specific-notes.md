# Version-Specific Breaking Changes

This document is the canonical reference for known breaking changes, required
actions, and behavioral differences for each Rails version hop.

When a section says "required action", that means the change will either raise
at boot or produce incorrect runtime behaviour if you do nothing.

For changes not listed here, always consult:
- Official upgrade guide: https://guides.rubyonrails.org/upgrading_ruby_on_rails.html
- Target version release notes: https://guides.rubyonrails.org/ → Release Notes
- Target version changelog on GitHub: https://github.com/rails/rails/blob/main/CHANGELOG.md

---

## Rails 6.0 → 6.1

**Official guide**: https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-6-0-to-rails-6-1

### Notable breaking changes

**`Rails.application.config_for` returns a HashWithIndifferentAccess**
- Previously returned a plain Hash with string keys.
- Required action: replace `config[:key]` accesses with `config["key"]` or
  migrate to `config[:key]` now that symbol access works.

**`respond_to#any` Content-Type behaviour changed**
- `respond_to { |f| f.any }` now returns the MIME type of the request, not
  `text/html`.
- Required action: audit controllers using `format.any` and verify responses.

**HTTPS redirect now uses 308**
- `config.force_ssl` redirects use HTTP 308 instead of 301.
- Required action: verify clients and load balancers handle 308 correctly.

**Active Storage requires `image_processing` gem**
- Image variants (`variant()`) now require the `image_processing` gem.
- Required action: add `gem 'image_processing', '~> 1.2'` to `Gemfile`.

**`ActiveModel::Error` is a class now**
- `errors[:field]` returns `ActiveModel::Error` objects, not strings.
- Required action: use `errors.full_messages` / `errors.map(&:message)` instead
  of treating elements as strings.

**`config.action_view.form_with_generates_remote_forms` default changed to `false`**
- `form_with` no longer submits via XHR by default.
- Required action: if you relied on the old default, add `local: false` to
  individual form calls or set the config back to `true`.

---

## Rails 6.1 → 7.0

**Official guide**: https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-6-1-to-rails-7-0

**Minimum Ruby**: 2.7.0

### Notable breaking changes

**Zeitwerk mode is now mandatory**
- The `classic` autoloader has been removed.
- Required action: if running in `classic` mode, follow the
  [Classic to Zeitwerk HOWTO](https://guides.rubyonrails.org/v7.0/classic_to_zeitwerk_howto.html).
- Check with: `bin/rails zeitwerk:check`

**`config.autoloader=` setter removed**
- Required action: remove any `config.autoloader = :zeitwerk` line (it is now
  the only mode).

**`ActiveSupport::Dependencies` private API removed**
- Methods like `hook!`, `depend_on`, `require_or_load`, `mechanism` are gone.
- Required action: replace `ActiveSupport::Dependencies.constantize("Foo")`
  with `"Foo".constantize`.

**Key generator digest changed from SHA1 to SHA256**
- Affects signed and encrypted cookies — existing sessions will be invalidated.
- Required action: add a cookie rotator to handle SHA1-signed cookies during
  the transition window:

```ruby
# config/initializers/cookie_rotator.rb
Rails.application.config.after_initialize do
  Rails.application.config.action_dispatch.cookies_rotations.tap do |cookies|
    secret = Rails.application.secret_key_base
    cookies.rotate :signed,    secret, digest: "SHA1"
    cookies.rotate :encrypted, secret, digest: "SHA1"
  end
end
```

**`ActionDispatch::Request#content_type` now returns full Content-Type header**
- Previously returned only the MIME type (no charset).
- Required action: use `request.media_type` where you need only the MIME type.

**`button_to` with a persisted Active Record object now generates PATCH**
- Required action: pass `method: :post` explicitly when you need POST.

**Sprockets is now optional**
- `rails` no longer depends on `sprockets-rails`.
- Required action: add `gem 'sprockets-rails'` if you still use Sprockets.

**`ActiveSupport::Dependencies` autoloading during initialisation is an error**
- Any constant autoloaded outside a `to_prepare` block now raises `NameError`.
- Required action: move such autoloads into `to_prepare` blocks or use
  `config.autoload_once_paths`.

**New cache format (7.0)**
- Required action for rolling deploys: leave the cache format unchanged on the
  first deploy to 7.0, then enable the new format on a subsequent deploy.

---

## Rails 7.0 → 7.1

**Official guide**: https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-7-0-to-rails-7-1

### Notable breaking changes

**`secret_key_base` file renamed**
- Dev/test: `tmp/development_secret.txt` → `tmp/local_secret.txt`
- Required action: rename the file or copy the key to avoid session/cookie
  invalidation in development and test.

**`alias_attribute` no longer calls custom reader methods**
- Required action: if you define a custom reader on an attribute and use
  `alias_attribute` to alias it, replace with `alias_method` or define the
  alias method manually.

**`config.action_dispatch.show_exceptions` values changed**
- Old: `true` / `false`
- New: `:all` / `:rescuable` / `:none`
- Required action: update `config/environments/test.rb` from
  `config.action_dispatch.show_exceptions = false` to
  `config.action_dispatch.show_exceptions = :none`.

**`$LOAD_PATH` no longer contains autoloaded directories (7.1 default)**
- Required action: do not `require` autoloaded files manually. If you must,
  add `config.add_autoload_paths_to_load_path = true` (not recommended).

**`ActiveStorage::BaseController` no longer includes streaming concern**
- Required action: if a controller inherits from `ActiveStorage::BaseController`
  and uses streaming, explicitly include `ActiveStorage::Streaming`.

**`MemCacheStore` / `RedisCacheStore` use connection pooling by default**
- Required action: if you do not want pooling, pass `pool: false`.

**`SQLite3Adapter` strict strings mode enabled by default**
- Double-quoted string literals treated as identifiers, not strings.
- Required action: audit SQLite queries. Disable with
  `config.active_record.sqlite3_adapter_strict_strings_by_default = false`
  if needed.

**`config.i18n.raise_on_missing_translations = true` now raises everywhere**
- Previously only raised in views/controllers.
- Required action: either add missing translations or set to `false`.

**Active Record Encryption digest changed to SHA-256**
- Required action: see the official guide for the migration steps for
  existing encrypted data.

**`Rails.logger` is now `ActiveSupport::BroadcastLogger`**
- `ActiveSupport::Logger.broadcast` API removed.
- Required action: replace `Rails.logger.extend(ActiveSupport::Logger.broadcast(logger))`
  with `Rails.logger.broadcast_to(logger)`.

**`@rails/ujs` import syntax changed**
- Required action: import the default export first:

```js
// Before
import { fileInputSelector } from "@rails/ujs"

// After
import Rails from "@rails/ujs"
const fileInputSelector = Rails.fileInputSelector
```

---

## Rails 7.1 → 7.2

**Official guide**: https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-7-1-to-rails-7-2

**Minimum Ruby**: 3.1.0

### Notable breaking changes

**All tests now respect `config.active_job.queue_adapter`**
- Required action: if you set a queue adapter in `config/application.rb` or
  `config/environments/test.rb` but wrote tests assuming `TestAdapter`, update
  those tests.

**`alias_attribute` change now fully active (announced in 7.1)**
- The deprecation warning from 7.1 is now a hard behaviour change.
- See 7.0→7.1 section above.

---

## Rails 7.2 → 8.0

**Official guide**: https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-7-2-to-rails-8-0

**Minimum Ruby**: 3.2.0

### New defaults introduced in 8.0

- `Regexp.timeout = 1` — protects against ReDoS attacks. A timeout of 1 second
  is set globally. Watch for slow regexes in your code that may now time out.
- `config.action_dispatch.strict_freshness = true` — `ETag`/`Last-Modified`
  freshness checking is stricter.

### Removals (all were deprecated in 7.x)

**Railties**
- `config.read_encrypted_secrets` removed.
- `rails/console/app` and `rails/console/helpers` files removed.
- `Rails::ConsoleMethods` extension mechanism removed.

**Action Pack**
- `config.action_controller.allow_deprecated_parameters_hash_equality` removed.

**Action View**
- `form_with(model: nil)` no longer accepted.
- Passing content to void tag elements via `tag` builder removed.

**Active Record**
- `config.active_record.commit_transaction_on_non_local_return` removed.
- `config.active_record.allow_deprecated_singular_associations_name` removed.
- Unregistered database adapter lookup removed.
- `enum` with keyword arguments syntax removed (use positional hash):

```ruby
# Before (deprecated in 7.x)
enum status: { active: 0, archived: 1 }, _default: :active

# After
enum :status, { active: 0, archived: 1 }, default: :active
```

- `config.active_record.warn_on_records_fetched_greater_than` removed.
- `ActiveRecord::ConnectionAdapters::ConnectionPool#connection` removed
  (use `#checkout` / `#with_connection`).

**Active Support**
- `ActiveSupport::ProxyObject` removed.
- `attr_internal_naming_format` with `@` prefix removed.
- Passing array of strings to `ActiveSupport::Deprecation#warn` removed.

**Active Job**
- `config.active_job.use_big_decimal_serializer` removed.

### Notable new features in 8.0

- **Solid Cable / Solid Cache / Solid Queue** — DB-backed alternatives to Redis
  for Action Cable, caching, and background jobs. New apps use them by default;
  existing apps can opt in.
- **Propshaft** is now the default asset pipeline (replaces Sprockets for new
  apps). Existing apps still using Sprockets continue to work; no forced
  migration.
- **Authentication generator** (`bin/rails generate authentication`) — creates
  a session-based, password-resettable auth skeleton. Optional.
- **`params#expect`** — safer strong parameters:

```ruby
# Old
params.require(:user).permit(:name, :email)

# New (Rails 8.0+)
params.expect(user: [:name, :email])
```

- **Kamal 2** — deployment config in `config/deploy.yml`.
- **`bin/rails db:migrate` on a fresh DB** now loads the schema first, then
  runs pending migrations. Use `db:migrate:reset` to force running all
  migrations from scratch.

---

## Rails 8.0 → 8.1

**Official guide**: https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-8-0-to-rails-8-1

**Minimum Ruby**: 3.2.0

### Notable changes

**`schema.rb` columns sorted alphabetically by default**
- Active Record now alphabetically sorts table columns in `schema.rb`.
- This may produce a large diff in your schema file on the first migrate.
- Required action: run `bin/rails db:schema:dump` and commit the re-sorted file.
  If you need exact column ordering, use `structure.sql` instead.

### New defaults in 8.1

- `config.action_controller.action_on_path_relative_redirect = :raise`
- `config.action_controller.escape_json_responses = false`
- `config.action_view.remove_hidden_field_autocomplete = true`
- `config.active_record.raise_on_missing_required_finder_order_columns = true`
- `config.yjit = !Rails.env.local?` — YJIT enabled by default in non-local
  environments. Disable with `config.yjit = false` if memory-constrained.

---

## Adding Support for a New Rails Version

When Rails X.Y is released, follow `maintainers/add-new-rails-version.md` first.
Then extend this document by adding a new section:

```markdown
## Rails (X-1).(Y-1 or 0) → X.Y

**Official guide**: <URL to upgrading guide>
**Minimum Ruby**: <version>

### Notable breaking changes
... (from the official upgrade guide + release notes changelogs)

### New defaults in X.Y
... (from `config/initializers/new_framework_defaults_X_Y.rb` in railsdiff.org)
```

Sources to consult for a new version:
1. `https://guides.rubyonrails.org/upgrading_ruby_on_rails.html`
2. `https://guides.rubyonrails.org/X_Y_release_notes.html`
3. `https://github.com/rails/rails/blob/X-Y-stable/CHANGELOG.md` (per-component)
4. `https://railsdiff.org/(prev)/(target)` for config file diffs
5. `https://www.fastruby.io/blog/rails/upgrade/rails-upgrade-series.html` for
   the FastRuby.io mini-guide once published
