import 'dart:async';

import 'package:flutter/painting.dart';

/// Pre-warms Flutter's [PaintingBinding.instance.imageCache] with a batch of
/// images from non-widget contexts (controllers, services, repositories) — no
/// [BuildContext] required.
///
/// Two entry points:
/// - [warm] — convenience for the common case (`NetworkImage` from URL
///   strings).
/// - [warmWith] — generic. Map each input through a builder to any
///   [ImageProvider] (`CachedNetworkImageProvider`, `NetworkImage` with custom
///   headers, `FileImage`, custom providers, ...).
///
/// Both share the same listener / completer / timeout / dedup pipeline.
///
/// ```dart
/// // Network — strings only:
/// await Overture.warm(<String>[
///   'https://example.com/a.png',
///   'https://example.com/b.png',
/// ]);
///
/// // Generic — pair with cached_network_image, headers, custom providers:
/// await Overture.warmWith(CachedNetworkImageProvider.new, urls);
/// ```
sealed class Overture {
  /// Pre-warms the Flutter image cache with the given network [urls].
  ///
  /// Convenience for the 80% case: URL strings into `NetworkImage`. Equivalent
  /// to `warmWith(NetworkImage.new, urls)`, with empty strings normalized to
  /// `null` (and therefore skipped).
  ///
  /// - `null` and empty URLs are skipped.
  /// - Duplicate URLs within the same call are dropped.
  /// - Per-URL errors are swallowed — warming must never throw.
  /// - The total wait is capped by [timeout] (default `5s`) so a slow item
  ///   doesn't block the caller forever.
  ///
  /// Completes when every URL has either loaded into
  /// [PaintingBinding.instance.imageCache] or failed individually, or when
  /// [timeout] elapses, whichever comes first.
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
  /// [builder] maps each non-null input to an [ImageProvider]. Lets you pair
  /// `overture` with any image-loading library that exposes an
  /// `ImageProvider`:
  ///
  /// ```dart
  /// // With cached_network_image (RAM warm + disk persistence):
  /// await Overture.warmWith(CachedNetworkImageProvider.new, urls);
  ///
  /// // Custom provider with auth headers:
  /// await Overture.warmWith(
  ///   (String url) => NetworkImage(url, headers: {'Authorization': token}),
  ///   urls,
  /// );
  ///
  /// // File-backed:
  /// await Overture.warmWith(FileImage.new, files);
  /// ```
  ///
  /// - `null` inputs are skipped.
  /// - Duplicate inputs (by `==` on `T`) are dropped within the same call.
  /// - Per-provider errors are swallowed — warming must never throw.
  /// - The total wait is capped by [timeout] (default `5s`).
  ///
  /// `T extends Object` so `Null` is forbidden as the input type — keeps the
  /// iterable element type unambiguously `T?`.
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
