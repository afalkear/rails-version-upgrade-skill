# Adding Support for a New Rails Version

Use this checklist when Rails releases a new minor or major version. Do not rely
on release notes alone; Rails release notes intentionally summarize major
changes and defer bug fixes and smaller changes to component changelogs.

## Workflow

1. Add a new node to `data/rails_versions.yml`.
2. Update the previous node's `next` value to point to the new version.
3. Add or verify the minimum Ruby version for the new target.
4. Read the official Rails upgrade guide for the new hop.
5. Read the target release notes.
6. Read framework changelogs for Railties, Action Pack, Action View, Active Record, Active Job, Action Mailer, Action Cable, Active Storage, and Active Support.
7. Review config diffs with RailsDiff or a freshly generated app.
8. Add a new section to `references/version-specific-notes.md` with required actions, removals, and new defaults.
9. Update `references/framework-defaults.md` with new `config.load_defaults` entries and risk tiers.
10. Update `references/risk-matrix.md` if the new release introduces a new class of upgrade risk.
11. Add false-positive notes for any pattern that sounds risky but is optional modernization only.
12. Run the skill against at least one sample app or real app and record gaps before publishing.

## Required Sources

- Official upgrade guide: https://guides.rubyonrails.org/upgrading_ruby_on_rails.html
- Rails release notes index: https://guides.rubyonrails.org/
- Rails changelogs: https://github.com/rails/rails/tree/main
- RailsDiff: https://railsdiff.org/
- Ruby/Rails compatibility table: https://www.fastruby.io/blog/ruby/rails/versions/compatibility-table.html

## Acceptance Criteria

- `data/rails_versions.yml` can produce a sequential path to the new version.
- The new hop has a clear version-specific section.
- Ruby compatibility gates are explicit.
- New framework defaults are documented separately from the Rails version bump.
- Optional modernizations are not presented as required upgrade work.
- The main `SKILL.md` does not need another hard-coded version sequence update.
