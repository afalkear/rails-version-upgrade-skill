# Upgrade Risk Matrix

Use this table during the planning phase to calibrate testing depth and
mitigation effort. Review it again when a hop produces unexpected failures.

| Risk | Likelihood | Impact | Detection | Primary mitigation |
|------|-----------|--------|-----------|-------------------|
| Ruby version incompatible with target Rails | Medium | Very high | Bundle/boot fails immediately | Upgrade Ruby first; pin supported versions |
| Gem set not compatible with target Rails/Ruby | High | Very high | Bundler conflicts, runtime boot errors | Inventory with `bundle outdated`; update stack in controlled waves; dual boot if needed |
| Zeitwerk / autoloading regressions | High on apps upgrading from 6.x | High | `zeitwerk:check`, eager-load failures, production boot errors | Fix file naming, autoload paths, and initialization patterns before or during each minor hop |
| Session / cookie invalidation | Medium | High | User logout spikes, auth errors in staging | Add cookie rotators before deploying; keep them until old cookies age out |
| Cache serialization / digest mismatch | Medium | Medium–High | Cache miss spikes, inconsistent read/write behavior | Preserve legacy cache format during rolling deploy; flip serializer after all nodes are updated |
| Job execution changes or transaction races | Medium | High | Job failures, flaky tests, race-condition bugs in staging | Make adapter explicit in tests; move enqueues to after-commit semantics |
| Asset pipeline / JS build breakage | High on legacy front ends | High | `assets:precompile` failures, missing assets in system tests | Decide explicitly: stay on Sprockets short-term or migrate asset stack as a separate workstream |
| Migration / schema bootstrap surprises | Medium | High | Fresh clone or CI bootstrap fails | Test `db:prepare` on a fresh schema in CI before deployment |
| Hidden production-only regressions | Medium | Very high | Only visible under real traffic, load, or multi-process model | Use staging close to production and canary deploy before flipping the last defaults |
