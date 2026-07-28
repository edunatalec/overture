# Changelog

## [0.1.2] - 2026-07-28

### Changed

- Reformatted the LICENSE into the canonical single-line-paragraph MIT template with a standardized copyright line — no change to the license terms.
- Adopted the stricter shared analysis options; no code changes were needed.

## [0.1.1] - 2026-07-28

### Changed

- Lowered the minimum SDK from Dart `^3.10.0` to `^3.8.0` — the only pinning feature was wildcard parameters (Dart 3.7), so the package installs on toolchains back to mid-2025.
- The `flutter` environment constraint now declares the real floor (`>=3.32.0`, the Flutter release paired with Dart 3.8) instead of the meaningless template default `>=3.0.0`.

## [0.1.0] - 2026-05-08

### Added

- Initial release.
- **`Overture.warm(urls, {timeout})`** — pre-warms `PaintingBinding.instance.imageCache` with a batch of network URLs from any non-widget code (no `BuildContext` required). Convenience for the common case: URL strings into `NetworkImage`.
- **`Overture.warmWith<T>(builder, inputs, {timeout})`** — generic warming with any `ImageProvider`. Pair `overture` with `cached_network_image` for disk persistence, custom providers with auth headers, file-based providers, etc. See README "Pairing with cached_network_image" for the canonical CNI integration pattern. `Overture.warm(urls)` is a thin wrapper over `warmWith<String>(NetworkImage.new, urls)` (with empty-string normalization).
- Shared semantics for both methods — `null` inputs skipped, duplicates dropped within a call, per-item errors swallowed (warming never throws), total wait capped by `timeout` (default `5s`).
