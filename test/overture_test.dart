import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overture/overture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeHttpClient client;

  setUp(() {
    client = _FakeHttpClient();
    debugNetworkImageHttpClientProvider = () => client;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  tearDown(() {
    debugNetworkImageHttpClientProvider = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  group('Overture.warm', () {
    test('returns immediately for an empty iterable', () async {
      await Overture.warm(<String?>[]);

      expect(client.requestCount, isEmpty);
    });

    test('deduplicates URLs within a call', () async {
      const String url = 'https://example.com/img-1.png';

      await Overture.warm(<String>[url, url, url]);

      expect(client.requestCount[url], 1);
    });

    test('skips null and empty entries without throwing', () async {
      const String url = 'https://example.com/img-1.png';

      await Overture.warm(<String?>[null, '', url, '', null]);

      expect(client.requestCount.length, 1);
      expect(client.requestCount[url], 1);
    });

    test('swallows individual errors and still warms the rest', () async {
      const String good1 = 'https://example.com/img-1.png';
      const String bad = 'https://example.com/error.png';
      const String good2 = 'https://example.com/img-2.png';

      await Overture.warm(<String>[good1, bad, good2]);

      expect(client.requestCount[good1], 1);
      expect(client.requestCount[bad], 1);
      expect(client.requestCount[good2], 1);
    });

    test('honors timeout when an item never resolves', () async {
      const String hang = 'https://example.com/hang.png';
      const Duration timeout = Duration(milliseconds: 200);

      final Stopwatch sw = Stopwatch()..start();
      await Overture.warm(<String>[hang], timeout: timeout);
      sw.stop();

      expect(sw.elapsed, greaterThanOrEqualTo(timeout));
      expect(sw.elapsed, lessThan(timeout + const Duration(seconds: 1)));
    });
  });

  group('Overture.warmWith', () {
    test('uses the builder to construct providers', () async {
      int built = 0;
      ImageProvider<Object> buildProvider(String url) {
        built++;

        return NetworkImage(url);
      }

      await Overture.warmWith(buildProvider, <String>[
        'https://example.com/img-1.png',
        'https://example.com/img-2.png',
      ]);

      expect(built, 2);
      expect(client.requestCount.length, 2);
    });

    test('deduplicates inputs by equality', () async {
      const String url = 'https://example.com/dup.png';

      await Overture.warmWith(NetworkImage.new, <String>[url, url, url]);

      expect(client.requestCount[url], 1);
    });

    test('skips nulls', () async {
      const String url = 'https://example.com/img-1.png';

      await Overture.warmWith<String>(NetworkImage.new, <String?>[
        null,
        url,
        null,
      ]);

      expect(client.requestCount.length, 1);
      expect(client.requestCount[url], 1);
    });

    test('honors timeout when a provider hangs', () async {
      const String hang = 'https://example.com/hang.png';
      const Duration timeout = Duration(milliseconds: 200);

      final Stopwatch sw = Stopwatch()..start();
      await Overture.warmWith(NetworkImage.new, <String>[
        hang,
      ], timeout: timeout);
      sw.stop();

      expect(sw.elapsed, greaterThanOrEqualTo(timeout));
      expect(sw.elapsed, lessThan(timeout + const Duration(seconds: 1)));
    });
  });

  test(
    'warm and warmWith with NetworkImage.new route through the same path',
    () async {
      const String viaWarm = 'https://example.com/via-warm.png';
      const String viaWarmWith = 'https://example.com/via-warmwith.png';

      await Overture.warm(<String>[viaWarm]);
      await Overture.warmWith(NetworkImage.new, <String>[viaWarmWith]);

      expect(client.requestCount[viaWarm], 1);
      expect(client.requestCount[viaWarmWith], 1);
    },
  );

  test(
    'completes via the success callback when a provider resolves cleanly',
    () async {
      // Drives the onImage branch of `_warmProvider`'s ImageStreamListener.
      // The network and asset fakes only exercise the onError branch because
      // the test binding rejects synthetic encoded bytes — this fake produces
      // a real ui.Image via Picture.toImage so the success path runs.
      await Overture.warmWith(_FakeSuccessImage.new, <String>['ok-1', 'ok-2']);

      final ImageCache cache = PaintingBinding.instance.imageCache;

      expect(cache.containsKey(const _FakeSuccessImage('ok-1')), isTrue);
      expect(cache.containsKey(const _FakeSuccessImage('ok-2')), isTrue);
    },
  );
}

class _FakeHttpClient extends Fake implements HttpClient {
  final Map<String, int> requestCount = <String, int>{};

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final String key = url.toString();
    requestCount.update(key, (int n) => n + 1, ifAbsent: () => 1);

    if (key.contains('/error')) {
      throw const SocketException('fake error');
    }

    if (key.contains('/hang')) {
      return _FakeHttpClientRequest(_HangResponse());
    }

    return _FakeHttpClientRequest(_EmptyResponse());
  }
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  _FakeHttpClientRequest(this._response);

  final HttpClientResponse _response;

  @override
  final HttpHeaders headers = _NoOpHeaders();

  @override
  Future<HttpClientResponse> close() async => _response;
}

class _NoOpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _EmptyResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  _EmptyResponse() : super(const Stream<List<int>>.empty());

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => 0;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HangResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  _HangResponse() : super(StreamController<List<int>>().stream);

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => -1;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSuccessImage extends ImageProvider<_FakeSuccessImage> {
  const _FakeSuccessImage(this.id);

  final String id;

  @override
  Future<_FakeSuccessImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_FakeSuccessImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _FakeSuccessImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_makeImageInfo());
  }

  Future<ImageInfo> _makeImageInfo() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xFF000000), BlendMode.src);
    final ui.Image image = await recorder.endRecording().toImage(1, 1);

    return ImageInfo(image: image);
  }

  @override
  bool operator ==(Object other) =>
      other is _FakeSuccessImage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
