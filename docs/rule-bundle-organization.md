# Rule Bundle Organization

## Purpose
This repo now separates bundled rule data by responsibility so verified site coverage, reusable auth workflows, and unresolved templates do not drift into a single monolithic fixture file.

## Bundle classes
- `legacy-sites.bundle.json`
  - Deprecated anonymous/public site providers whose live hosts are no longer treated as current coverage.
  - Not merged into `RuleBundleFixtures.defaultBundle`.
  - Tests that need these legacy rules must load this bundle explicitly.
- `auth-workflows.bundle.json`
  - Active reusable auth workflows only.
  - No providers.
  - Capability refs should be the minimum set needed by those workflows.
- `auth-sites.bundle.json`
  - Verified authenticated site providers.
  - Hosts must be backed by source evidence from repo code, tests, or an external source note.
  - May include site-specific download workflows when the authenticated flow is verified.
- `auth-templates.bundle.json`
  - Unverified or example auth providers and legacy auth workflows kept for engine/testing coverage.
  - Not merged into `RuleBundleFixtures.defaultBundle`.
  - Tests that need these templates must load this bundle explicitly.

## Default catalog
`RuleBundleFixtures.defaultBundle` merges only:
- `auth-workflows.bundle`
- `auth-sites.bundle`

This keeps the default runtime catalog free of example hosts.
It also keeps deprecated public providers out of active resolution.

## Release flow
Do not manually copy verified JSON into the Admin app. Treat `WebShell-SPM` bundled rule resources as the source of truth:
- Land verified provider/workflow changes in `Sources/WebShellEngine/Resources/RuleBundles/`.
- Bump `RuleBundleFixtures.defaultBundle` to a new unique catalog `bundleVersion`; this avoids Postgres duplicate-version publish failures.
- Run `cd WebShell-SPM && swift test`.
- Publish the default bundle through the control plane, either from Admin UI after rebuilding against the updated `WebShell-SPM`, or from the smoke publisher:
  `cd WebShellClient-Apple/Packages/WebShellClientKit && swift run WebShellClientSmoke publish-default-bundle --control-plane-url http://127.0.0.1:8089 --target-group <target> --note "<release note>" --bundle-version <catalog-version>`
- After publish, refresh Admin Releases and Client Settings/Rules; the active bundle version should match the published catalog version.

## Promotion rules
Move a provider from `auth-templates.bundle.json` to `auth-sites.bundle.json` only when all of the following are true:
- The host is real and attributable.
- The auth entry path is known.
- The material requirements are known.
- The download flow is either verified or clearly marked as a temporary adapter.
- Captcha auth flows have a verified retry policy:
  - use `captchaRetryPolicy.mode = refreshCaptcha` when the provider supports same-session captcha refresh; these providers may use a higher retry budget such as 50 attempts
  - use `captchaRetryPolicy.mode = fullWorkflow` or omit the policy when the provider requires a fresh login page or cookie before each captcha attempt

## Current status
- Verified auth sites in default catalog: `jkpan-vip`, `116pan-vip`, `koolaayun-vip`
- Legacy-only public providers: `rosefile`, `xueqiupan`, `xunniufile`, `xingyaoclouds`, `rarp`, `567file`, `iycdn`
- Template-only auth providers: `secure-demo`, `xrcf-vip`
