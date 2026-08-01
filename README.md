[![pub package](https://img.shields.io/pub/v/overture.svg)](https://pub.dev/packages/overture)
[![package publisher](https://img.shields.io/pub/publisher/overture.svg)](https://pub.dev/packages/overture/publisher)

<img src="https://github.com/edunatalec/overture/raw/master/assets/demo.gif" alt="Overture demo — left column hits the network, right column was pre-warmed and renders instantly" width="240" />

A tiny, dependency-free Flutter utility that pre-warms `PaintingBinding.instance.imageCache` **from any non-widget code** — controllers, services, repositories — without needing a `BuildContext`. Pairs naturally with `Image.network`, `cached_network_image`, or any other image widget: they all read the same global `imageCache`. It warms RAM only — no disk cache.

## Requirements

Flutter 3.32 or newer, which ships Dart 3.8:

```sh
flutter --version
```

## Installation

```sh
flutter pub add overture
```

Or in `pubspec.yaml`:

```yaml
dependencies:
  overture: ^0.1.3
```

```dart
import 'package:overture/overture.dart';
```

## Quick start

Warm the cache from any non-widget code, then build your widgets normally — the first frame finds the bitmaps already decoded.

```dart
import 'package:overture/overture.dart';

class GalleryController {
  GalleryState state = const GalleryState.idle();

  Future<void> load() async {
    final List<Photo> photos = await api.fetchPhotos();

    // Pre-warm the image cache before flipping to the "ready" state.
    await Overture.warm(photos.map((Photo p) => p.thumbnailUrl));

    state = GalleryState.ready(photos);
  }
}
```

```dart
// Later, in a widget — no flicker, no spinner on the first frame.
GridView.count(
  crossAxisCount: 2,
  children: <Widget>[
    for (final Photo p in photos) Image.network(p.thumbnailUrl),
  ],
)
```

Need something other than `NetworkImage` from a URL? Reach for `warmWith` — it accepts any builder that returns an `ImageProvider`:

```dart
// Disk persistence via cached_network_image.
await Overture.warmWith(CachedNetworkImageProvider.new, urls);

// Authenticated requests with a custom header builder.
await Overture.warmWith(
  (String url) => NetworkImage(url, headers: <String, String>{
    'Authorization': 'Bearer $token',
  }),
  urls,
);

// File-backed images (e.g. local cache, generated thumbnails).
await Overture.warmWith(FileImage.new, files);

// Bundled assets — read the AssetImage caveat below before relying on this
// for DPR-variant assets (1.5x, 2x, 3x).
await Overture.warmWith(AssetImage.new, <String>[
  'assets/onboarding/hero.png',
  'assets/icons/logo.png',
]);

// Cross-package assets — microapp / multi-package setups where each image
// lives in a different Flutter package. The closure captures `package` so
// every entry resolves under `packages/<pkg>/...` automatically.
await Overture.warmWith(
  (String name) => AssetImage(name, package: 'design_system'),
  <String>['assets/icons/logo.png', 'assets/icons/badge.png'],
);
```

`warm` and `warmWith` both return a `Future<void>` that completes when every entry has loaded into the cache (or failed individually), or when the `timeout` elapses — whichever comes first. **Neither ever throws.**

## Contents

- [Why overture](#why-overture)
- [API](#api)
- [How it works](#how-it-works)
- [Pairing with cached_network_image](#pairing-with-cached_network_image)
- [Caveats](#caveats)
- [Why the name](#why-the-name)
- [Example app](#example-app)
- [Contributing](#contributing)
- [License](#license)

## Why overture

- **Context-free** — call from controllers, repositories, services, anywhere. No `BuildContext` required.
- **String shortcut + generic escape hatch** — `Overture.warm(urls)` for the URL case, `Overture.warmWith(builder, inputs)` for any `ImageProvider` (CNI, custom headers, file-backed, etc.).
- **Drop-in cache hit** — uses the exact same key the widget will compute, so the next render paints synchronously from cache.
- **Forgiving** — null/empty entries skipped, duplicates dropped, per-item errors swallowed.
- **Bounded** — total wait is capped by `timeout` (default `5s`); never blocks the caller forever.
- **RAM only** — no disk cache. Pair it with `cached_network_image` when the bytes have to survive an app restart.
- **Zero dependencies** — `flutter` only. No transitive surprises.

Flutter's built-in `precacheImage(provider, context)` requires a `BuildContext`. That's a poor fit for clean-architecture apps where the data layer (controllers, services, repositories) shouldn't depend on Flutter's widget tree — and it's awkward to call from a route guard, a background fetch, a stream listener, or anywhere else outside `build()`. `Overture.warm` does the same job without the context: pass it the URLs as soon as they arrive (right after a JSON fetch is the canonical spot) and the bitmaps are decoded into the global `imageCache` while the rest of your app is still composing the UI.

The payoff is **perceived UI quality**. When the widget tree finally builds, every `Image.network(url)` finds the bitmap already in cache and paints synchronously on the first frame — no progress spinners, no fade-in, no layout shift, no flash of placeholder. For galleries, lists with thumbnails, hero transitions, and any flow where the user notices the difference between "blank → loading → image" and "image, instantly", warming the cache up-front turns a janky reveal into a clean one.

## API

```dart
sealed class Overture {
  static Future<void> warm(
    Iterable<String?> urls, {
    Duration timeout = const Duration(seconds: 5),
  });

  static Future<void> warmWith<T extends Object>(
    ImageProvider Function(T) builder,
    Iterable<T?> inputs, {
    Duration timeout = const Duration(seconds: 5),
  });
}
```

| Method                      | When to use                                                                                                                                                     |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `warm(urls)`                | Default. URL strings + plain `NetworkImage`. The 80% case.                                                                                                      |
| `warmWith(builder, inputs)` | When you need a different `ImageProvider`: `CachedNetworkImageProvider` for disk persistence, `NetworkImage` with custom headers, `FileImage`, anything custom. |

`warm(urls)` is a thin wrapper over `warmWith<String>(NetworkImage.new, urls)` (with empty strings normalized to `null`). The two paths share the same dedup / listener / timeout pipeline, so behavior is identical except for the input shape.

**Behavior shared by both methods:**

- `null` entries are skipped (and empty strings for `warm`) — pass nullable iterables straight from a model without filtering first.
- Duplicates within the same call are dropped — `warm` dedups by URL string, `warmWith` dedups by `==` on `T`.
- Per-item errors are swallowed. Whether a URL 404s, hits a `SocketException`, or the bytes don't decode, the future for that single item completes silently and the rest keep going. **Warming never throws.**
- The total wait is capped by `timeout` — a slow CDN or hung connection cannot block the caller indefinitely. Items still in flight when the timeout fires are not cancelled (they may eventually populate the cache anyway), but the future returns.

## How it works

Flutter's image cache is a global `ImageCache` instance on `PaintingBinding`, keyed by `ImageProvider`. `NetworkImage.obtainKey()` returns `SynchronousFuture(this)` with `==` over `(url, scale, headers)`; `CachedNetworkImageProvider` is keyed similarly. `overture` resolves each provider against `ImageConfiguration.empty`, which lands on the **same key** the widget will compute later when there's no DPR-dependent variant in play. The result: a guaranteed cache hit when the widget renders, and the first frame paints the bitmap synchronously from RAM.

## Pairing with cached_network_image

`overture` only warms RAM. For cross-session offline rendering, pair it with [`cached_network_image`](https://pub.dev/packages/cached_network_image):

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:overture/overture.dart';

class GalleryController {
  Future<void> load() async {
    final List<Photo> photos = await api.fetchPhotos();

    // Warm Flutter's imageCache via CNI's provider — populates RAM
    // *and* CNI's disk cache in one pass.
    await Overture.warmWith(
      CachedNetworkImageProvider.new,
      photos.map((Photo p) => p.url),
    );

    state = GalleryState.ready(photos);
  }
}

// Render with the same provider — cache hit on first frame.
CachedNetworkImage(imageUrl: photo.url);
```

The pair gives you:

- **First load** — `Overture.warmWith` runs the GETs in parallel during your spinner; first render is synchronous from RAM.
- **Cross-session** — CNI persists bytes to disk. App reopen → `warmWith` reads from disk (~10–50 ms per image), no network.

The two libraries cooperate via the global `imageCache`. Both prefetch and render use `CachedNetworkImageProvider(url)` as the key, so they hit the same cache entry.

## Caveats

- `overture` resolves providers with `ImageConfiguration.empty`. That's fine for providers whose cache key is configuration-independent (`NetworkImage`, `CachedNetworkImageProvider`, `FileImage`). For `AssetImage`, the resolution depends on the asset shape:
  - **Single-resolution assets** (one file per logical asset, no `1.5x/`, `2x/`, `3x/` variants in `pubspec.yaml`) — the cache key is stable and `Overture.warmWith(AssetImage.new, ...)` lands on the same key the widget will compute. Works fine.
  - **DPR-variant assets** — `AssetImage.obtainKey` picks the variant from `configuration.devicePixelRatio`. With `ImageConfiguration.empty` the DPR is `null` and the resolved key may differ from the widget's at render time, leading to a cache miss. First-class asset support with explicit DPR plumbing is on the roadmap.
- Items still in flight when `timeout` fires are not cancelled. They may eventually populate the cache anyway, but the future returns.

## Why the name

In an opera, the _overture_ is the orchestral piece that plays before the curtain rises — it sets the mood while the audience settles in, so the moment the stage lights come up the show starts clean. This package does the same for your image cache: it warms the bitmaps in RAM while the app is still composing the UI, so the first frame paints without flicker.

## Example app

A demo app lives in [`example/`](https://github.com/edunatalec/overture/tree/master/example). It shows two columns side-by-side: the left renders cold (`Image.network` straight to the network), the right was pre-warmed with `Overture.warm` before render. Tap "Load 6 images" to see the difference: the right column paints instantly from cache while the left shows a spinner per tile. Run it with:

```sh
cd example
flutter create .   # generate platform folders the first time
flutter run
```

## Contributing

[CONTRIBUTING.md](https://github.com/edunatalec/overture/blob/master/CONTRIBUTING.md) is the contract for whoever writes code here: the one command that has to be green before a pull request, what the two CI jobs check, the conventions, and the deliberate gaps a PR should not try to fix.

## License

MIT — see [LICENSE](https://github.com/edunatalec/overture/blob/master/LICENSE).
