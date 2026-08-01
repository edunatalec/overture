/// @docImport 'package:flutter/widgets.dart';
library;

import 'dart:async';

import 'package:flutter/painting.dart';

/// Pre-warms the [ImageCache] on [PaintingBinding] with a batch of images, from
/// non-widget contexts (controllers, services, repositories) — no
/// [BuildContext] required.
///
/// A [BuildContext] is the one thing Flutter's own `precacheImage` needs, and
/// only to derive an [ImageConfiguration]. This resolves against
/// [ImageConfiguration.empty] instead, which yields the very same cache key for
/// every provider whose key ignores the configuration — [NetworkImage],
/// [FileImage], `CachedNetworkImageProvider` — so the widget that renders later
/// finds the bitmap already decoded and paints it on its first frame.
///
/// Two entry points:
/// - [warm] — convenience for the common case ([NetworkImage] from URL
///   strings).
/// - [warmWith] — generic. Map each input through a builder to any
///   [ImageProvider] (`CachedNetworkImageProvider`, [NetworkImage] with custom
///   headers, [FileImage], custom providers, ...).
///
/// Both share the same listener / completer / timeout / dedup pipeline.
///
/// ```dart
/// await Overture.warm(<String>[
///   'https://example.com/a.png',
///   'https://example.com/b.png',
/// ]);
/// ```
///
/// See also:
///
///  * [warm], the convenience path for network URLs.
///  * [warmWith], the generic path for any [ImageProvider].
sealed class Overture {
  /// Pre-warms the Flutter image cache with the given network [urls].
  ///
  /// Convenience for the 80% case: URL strings into [NetworkImage]. Equivalent
  /// to [warmWith] with `NetworkImage.new` as the builder, with empty strings
  /// normalized to `null` (and therefore skipped).
  ///
  /// - `null` and empty URLs are skipped.
  /// - Duplicate URLs within the same call are dropped.
  /// - Per-URL errors are swallowed — warming must never throw.
  /// - The total wait is capped by [timeout] (default `5s`) so a slow item
  ///   doesn't block the caller forever.
  ///
  /// Completes when every URL has either loaded into the [ImageCache] or failed
  /// individually, or when [timeout] elapses, whichever comes first. Items
  /// still in flight when [timeout] fires are not cancelled and may populate
  /// the cache later.
  ///
  /// ```dart
  /// await Overture.warm(
  ///   <String?>[
  ///     'https://example.com/a.png',
  ///     null,
  ///     'https://example.com/b.png',
  ///   ],
  ///   timeout: const Duration(seconds: 3),
  /// );
  /// ```
  ///
  /// See also:
  ///
  ///  * [warmWith], for any [ImageProvider] other than a plain [NetworkImage].
  static Future<void> warm(
    Iterable<String?> urls, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return warmWith<String>(
      NetworkImage.new,
      urls.map((String? url) => (url != null && url.isNotEmpty) ? url : null),
      timeout: timeout,
    );
  }

  /// Pre-warms the Flutter image cache with arbitrary [ImageProvider]s.
  ///
  /// [builder] maps each non-null input to an [ImageProvider], which is what
  /// lets `overture` warm the cache through any image-loading library that
  /// exposes one — `CachedNetworkImageProvider` for disk persistence, a
  /// [NetworkImage] carrying auth headers, a [FileImage], a provider of your
  /// own.
  ///
  /// - `null` inputs are skipped.
  /// - Duplicate inputs (by `==` on `T`) are dropped within the same call.
  /// - Per-provider errors are swallowed — warming must never throw.
  /// - The total wait is capped by [timeout] (default `5s`).
  ///
  /// `T extends Object` so `Null` is forbidden as the input type — keeps the
  /// iterable element type unambiguously `T?`.
  ///
  /// [AssetImage] is the one provider to watch: its key depends on the device
  /// pixel ratio carried by the [ImageConfiguration], so an asset declared with
  /// `1.5x` / `2x` / `3x` variants may resolve here to a key the widget never
  /// computes. Single-resolution assets are safe.
  ///
  /// ```dart
  /// await Overture.warmWith(
  ///   (String url) => NetworkImage(
  ///     url,
  ///     headers: const <String, String>{'Authorization': 'Bearer <token>'},
  ///   ),
  ///   <String>['https://example.com/private.png'],
  /// );
  ///
  /// await Overture.warmWith(AssetImage.new, <String>[
  ///   'assets/onboarding/hero.png',
  /// ]);
  /// ```
  ///
  /// See also:
  ///
  ///  * [warm], the shorter path when the inputs are plain network URLs.
  static Future<void> warmWith<T extends Object>(
    ImageProvider<Object> Function(T) builder,
    Iterable<T?> inputs, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final Set<T> seen = <T>{};
    final List<Future<void>> tasks = <Future<void>>[];

    for (final T? input in inputs) {
      if (input == null) continue;
      if (!seen.add(input)) continue;

      tasks.add(_warmProvider(builder(input)));
    }

    if (tasks.isEmpty) return;

    await Future.wait(tasks).timeout(timeout, onTimeout: () => const <void>[]);
  }

  static Future<void> _warmProvider(ImageProvider<Object> provider) {
    final Completer<void> completer = Completer<void>();
    final ImageStream stream = provider.resolve(ImageConfiguration.empty);

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
      onError: (_, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
    );

    stream.addListener(listener);

    return completer.future;
  }
}
