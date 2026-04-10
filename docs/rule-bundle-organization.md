# Rule Bundle Organization

## Purpose
This repo now separates bundled rule data by responsibility so verified site coverage, reusable auth workflows, and unresolved templates do not drift into a single monolithic fixture file.

## Bundle classes
- `public-sites.bundle.json`
  - Verified anonymous/public site providers.
  - May include only download workflows required by those providers.
  - Must not include auth-only template providers.
- `auth-workflows.bundle.json`
  - Reusable auth workflows only.
  - No providers.
  - Capability refs should be the minimum set needed by those workflows.
- `auth-sites.bundle.json`
  - Verified authenticated site providers.
  - Hosts must be backed by source evidence from repo code, tests, or an external source note.
  - May include site-specific download workflows when the authenticated flow is verified.
- `auth-templates.bundle.json`
  - Unverified or example auth providers kept for engine/testing coverage.
  - Not merged into `RuleBundleFixtures.defaultBundle`.
  - Tests that need these templates must load this bundle explicitly.

## Default catalog
`RuleBundleFixtures.defaultBundle` merges only:
- `public-sites.bundle`
- `auth-workflows.bundle`
- `auth-sites.bundle`

This keeps the default runtime catalog free of example hosts.

## Promotion rules
Move a provider from `auth-templates.bundle.json` to `auth-sites.bundle.json` only when all of the following are true:
- The host is real and attributable.
- The auth entry path is known.
- The material requirements are known.
- The download flow is either verified or clearly marked as a temporary adapter.

## Current status
- Verified auth site in default catalog: `jkpan-vip`
- Template-only auth providers: `secure-demo`, `xrcf-vip`
