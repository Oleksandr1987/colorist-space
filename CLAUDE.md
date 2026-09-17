# CLAUDE.md

Guidance for Claude when reviewing pull requests on this repository.

## Project context

- Ruby on Rails 8, Ruby 3.3
- Hotwire: Turbo (turbo-rails) + Stimulus (stimulus-rails)
- RSpec (rspec-rails, factory_bot_rails) for tests
- ActiveRecord + Active Storage
- Devise-based auth (omniauth-rails_csrf_protection present)
- I18n: Ukrainian is the default locale, English is supported. Locale files are split per domain (e.g. `config/locales/clients.en.yml` / `clients.uk.yml`, `analytics.*`, `formula.*`, etc.) rather than one big file per language.
- This is a multi-user application (colorists managing their own clients, appointments, formulas, etc.) — **user data isolation is a top-priority correctness concern**. Assume any model that belongs to a user (clients, appointments, formulas, services, care products, analytics records, etc.) must never be readable or writable by a different user.

## What to focus on

Find real bugs and regressions — not cosmetic issues. For every issue found, explain:

1. What can go wrong
2. Under what conditions it happens
3. The relevant code/location
4. A concrete suggested fix

Prioritize by severity (data leaks/corruption > incorrect behavior > performance > missing test coverage) and avoid flooding the PR with low-value comments. A handful of high-confidence findings beats an exhaustive list.

### Data isolation & authorization

- Every controller action and query touching user-owned records must be scoped to `current_user` (or the correctly authorized owner) — watch for `Model.find(params[:id])` instead of `current_user.models.find(params[:id])`.
- Watch for IDs taken from params/forms (including nested attributes and hidden fields) that could let one user reference or modify another user's records.
- Check that associations, includes, and joins don't accidentally cross user boundaries (e.g. a global lookup table joined without a scope check).

### ActiveRecord & database

- Look for N+1 queries, especially in views/partials that loop over associations without `includes`/`preload`/`eager_load`.
- Look for unnecessary queries inside loops, or repeated queries that could be batched.
- Check validations for correctness and for missing DB-level constraints (uniqueness scoped correctly, not-null, foreign keys) where the app relies on them for integrity.
- Check callbacks (`before_save`, `after_commit`, etc.) for unexpected side effects, ordering issues, or callback loops (e.g. a callback that re-triggers the same save/update cycle).
- Check nested attributes (`accepts_nested_attributes_for`) carefully: `_destroy`, `reject_if`, ownership of nested records, and whether nested params could be used to attach/detach records belonging to another user.
- Check SQL/query performance for anything that could scale badly (missing indexes implied by new query patterns, unbounded scopes, unnecessary `.to_a`/loading full tables).

### Turbo & Stimulus

- Check Turbo Stream/Frame responses for correctness (right target, right action) and that they won't break on partial page updates.
- Check Stimulus controllers for: duplicate event listeners (listeners added without being removed), correct `connect()`/`disconnect()` symmetry (anything bound in `connect` should be unbound in `disconnect`), stale state carried across Turbo navigations, and duplicated/double-fired events.
- Check for race conditions and DOM lifecycle issues caused by Turbo Drive navigation/caching (code assuming a full page load, timers/listeners not cleaned up before Turbo swaps the page, code that queries the DOM before Turbo has finished rendering).

### Active Storage

- Check that attachments are scoped/authorized to the owning user (no ability to view/download another user's uploaded files via guessable/direct blob or attachment URLs).
- Check that attaching, replacing, and purging blobs doesn't leave orphaned or duplicated records, and that ownership is validated before attaching.

### I18n

- Flag new hardcoded user-facing strings in views, flash messages, Stimulus/JS-rendered text, or error messages that should go through `I18n.t` instead.
- Check that new keys are added to both the Ukrainian and English locale files (not just one), and in the correct per-domain file matching the existing split convention.

### Security

- Standard Rails security concerns: mass assignment via strong parameters, missing authorization checks, SSRF/open redirects, unsafe `raw`/`html_safe` usage, unsafe query interpolation (SQL injection via string-built `where`), missing CSRF protections on new endpoints.

### Background jobs

- Check jobs for idempotency where relevant (safe to retry/run twice without duplicating side effects), and that they re-scope/re-authorize data rather than trusting IDs passed in without re-checking ownership.

### Tests

- Check whether bug fixes and behavior changes come with regression specs.
- Check existing RSpec specs for incorrect expectations, or missing edge cases relevant to the change (not a general audit of unrelated specs).

### Code quality

- Prefer simple Rails conventions over unnecessary custom complexity.
- Point out duplicated code only when it creates a real maintenance or correctness risk (e.g. duplicated authorization logic that could drift out of sync).

## Do not report

- Trivial formatting
- Subjective style preferences
- Minor naming preferences
- Unrelated pre-existing issues outside the diff
- Speculative problems without a concrete failure scenario
<!-- Claude Code background agents test -->
