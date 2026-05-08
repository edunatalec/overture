# Changelog

## [0.1.0] - 2026-05-08

### Added

- Initial release.
- **`Overture.warm(urls, {timeout})`** — pre-warms `PaintingBinding.instance.imageCache` with a batch of network URLs from any non-widget code (no `BuildContext` required). Convenience for the common case: URL strings into `NetworkImage`.
- **`Overture.warmWith<T>(builder, inputs, {timeout})`** — generic warming with any `ImageProvider`. Pair `overture` with `cached_network_image` for disk persistence, custom providers with auth headers, file-based providers, etc. See README "Pairing with cached_network_image" for the canonical CNI integration pattern. `Overture.warm(urls)` is a thin wrapper over `warmWith<String>(NetworkImage.new, urls)` (with empty-string normalization).
- Shared semantics for both methods — `null` inputs skipped, duplicates dropped within a call, per-item errors swallowed (warming never throws), total wait capped by `timeout` (default `5s`).
