# Rails Version Upgrade Skill

A reusable agent skill for upgrading Ruby on Rails applications across sequential version hops, including Ruby version alignment, dual boot, gem compatibility, framework defaults, validation, and broken-build triage.

Includes a dedicated Rails 7.2 to Rails 8.0 focused playbook with Rails 8.0 removals, Ruby 3.2 gating, optional modernization boundaries, and validation checklists.

The [version graph](data/rails_versions.yml) includes 7.0 → 7.1, 7.2 → 8.0
and 8.0 → 8.1, with Ruby compatibility gates for each hop.
See [per-hop notes](references/version-specific-notes.md) and
[framework defaults](references/framework-defaults.md) before changing Rails.

## Install

```bash
npx skills add afalkear/rails-version-upgrade-skill
```

Verify the installed directory contains `data/`, `references/` and
`maintainers/` alongside `SKILL.md`. A standalone copy of `SKILL.md` is
incomplete. For a manual installation, copy this repository's skill resources
together, preserving their relative paths.

## Validate

```bash
ruby test/version_graph_test.rb
```

This checks graph traversal, Ruby gates and guide targets with sample preflight
inputs. It does not substitute for an application's baseline or upgraded suite.

## Update

```bash
npx skills update afalkear/rails-version-upgrade-skill
```

## Repository

https://github.com/afalkear/rails-version-upgrade-skill
