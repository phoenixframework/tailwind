# CHANGELOG

## v0.2.2 (2023-11-03)
* Fix Elixir v1.16 errors where tailwind would not yet be started

## v0.2.1 (2023-06-26)
* Support Elixir v1.15+ by ensuring inets and ssl are available even on `runtime: false`

## v0.2.0 (2023-03-16)
* Require Elixir v1.11+

## v0.1.10 (2023-02-09)
* Declare inets and ssl for latest elixir support
* Add FreeBSD targets
* Add armv7 targets
* Support custom URLs for fetching prebuilt tailwind binaries

## v0.1.9 (2022-09-06)

* Use only TLS 1.2 on OTP versions less than 25.

## v0.1.8 (2022-07-14)

* Fix generated tailwind.config.js missing plugin reference

## v0.1.7 (2022-07-13)

* Bump tailwindcss to v3.1.6
* Add Phoenix LiveView variants

## v0.1.6 (2022-06-09)

* Bump tailwindcss to v3.1.0

## v0.1.5 (2022-01-18)

* Prune app.js css import to remove required manual step on first install

## v0.1.4 (2022-01-07)

* Bump tailwindcss to v3.0.12 to support alpine linux and others requiring statically linked builds

## v0.1.3 (2022-01-04)

* Bump tailwindcss to v3.0.10
* Inject tailwind imports into app.css on install
* Prune phoenix.css import from app.css on install

## v0.1.2 (2021-12-21)

* Fix tailwind v3 warnings and simplify generated `assets/tailwind.config.js` configuration

## v0.1.1 (2021-12-20)

* First release
