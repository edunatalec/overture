/// Pre-warms Flutter's image cache from non-widget code, so the first frame
/// that shows an image paints it straight from RAM.
///
/// Flutter keeps a single [ImageCache] on [PaintingBinding], keyed by
/// [ImageProvider]. Resolving a provider ahead of time decodes the bitmap into
/// that cache under exactly the key a widget computes later, which turns the
/// usual blank → spinner → image reveal into one clean frame.
///
/// Nothing here touches the widget tree: there is no [BuildContext] to pass and
/// no widget to adopt, so a controller, repository or service can warm the
/// cache the moment the URLs arrive — and every image widget benefits, because
/// they all read the same global cache.
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
///  * [Overture.warm], which warms a batch of network URLs.
///  * [Overture.warmWith], which warms any [ImageProvider] — a provider with
///    custom headers, a file-backed one, or one from another package.
library;

import 'package:flutter/widgets.dart';

export 'src/overture.dart';
