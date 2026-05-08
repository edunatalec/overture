import 'package:flutter/material.dart';
import 'package:overture/overture.dart';

void main() {
  runApp(const OvertureExampleApp());
}

class OvertureExampleApp extends StatelessWidget {
  const OvertureExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Overture demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),
      ),
      home: const _GalleryPage(),
    );
  }
}

class _GalleryPage extends StatefulWidget {
  const _GalleryPage();

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

typedef _BatchUrls = ({List<String> cold, List<String> warmed});

class _GalleryPageState extends State<_GalleryPage> {
  static const int _imagesPerSide = 3;

  int _batch = 0;
  bool _loading = false;
  List<String> _coldUrls = const <String>[];
  List<String> _warmedUrls = const <String>[];

  _BatchUrls _urlsForBatch(int batch) {
    return (
      cold: <String>[
        for (int i = 1; i <= _imagesPerSide; i++)
          'https://picsum.photos/seed/overture-$batch-cold-$i/600/600',
      ],
      warmed: <String>[
        for (int i = 1; i <= _imagesPerSide; i++)
          'https://picsum.photos/seed/overture-$batch-warm-$i/600/600',
      ],
    );
  }

  Future<void> _loadImages() async {
    final int nextBatch = _batch + 1;
    final _BatchUrls next = _urlsForBatch(nextBatch);

    setState(() {
      _loading = true;
      _coldUrls = const <String>[];
      _warmedUrls = const <String>[];
    });

    // Pre-warm only the right column. Left column stays cold so the
    // loading spinners are visible per tile and the contrast pops.
    await Overture.warm(next.warmed);

    if (!mounted) return;

    setState(() {
      _loading = false;
      _batch = nextBatch;
      _coldUrls = next.cold;
      _warmedUrls = next.warmed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme typo = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _HeroCard(
                onLoad: _loading ? null : _loadImages,
                loading: _loading,
                batch: _batch,
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildBody()),
              const SizedBox(height: 14),
              Text(
                'Right column was pre-warmed via Overture.warm before render — '
                'first frame paints from RAM. Left column hits the network on demand.',
                textAlign: TextAlign.center,
                style: typo.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme typo = Theme.of(context).textTheme;
    final bool ready = _coldUrls.isNotEmpty && _warmedUrls.isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: ready
          ? Row(
              key: const ValueKey<String>('grid'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _DemoColumn(
                    label: 'No cache',
                    warmed: false,
                    urls: _coldUrls,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DemoColumn(
                    label: 'Pre-warmed',
                    warmed: true,
                    urls: _warmedUrls,
                  ),
                ),
              ],
            )
          : Center(
              key: ValueKey<String>(_loading ? 'loading' : 'idle'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _loading
                          ? Icons.local_fire_department_rounded
                          : Icons.image_outlined,
                      size: 44,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _loading
                        ? 'Pre-warming the cache…'
                        : 'Tap the button to start',
                    style: typo.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.onLoad,
    required this.loading,
    required this.batch,
  });

  final VoidCallback? onLoad;
  final bool loading;
  final int batch;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme typo = Theme.of(context).textTheme;
    final bool hasLoaded = batch > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[scheme.primaryContainer, scheme.secondaryContainer],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: scheme.onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Overture',
                      style: typo.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Warm the image cache before render',
                      style: typo.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (hasLoaded)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey<int>(batch),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Batch #$batch',
                      style: typo.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onLoad,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            icon: loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(
              loading
                  ? 'Pre-warming…'
                  : (hasLoaded ? 'Load 6 new images' : 'Load 6 images'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoColumn extends StatelessWidget {
  const _DemoColumn({
    required this.label,
    required this.warmed,
    required this.urls,
  });

  final String label;
  final bool warmed;
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = warmed
        ? scheme.primary
        : scheme.surfaceContainerHigh;
    final Color foreground = warmed ? scheme.onPrimary : scheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                warmed ? Icons.bolt_rounded : Icons.hourglass_empty_rounded,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: foreground,
                  letterSpacing: 0.4,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < urls.length; i++) ...<Widget>[
                Expanded(child: _ImageTile(url: urls[i])),
                if (i < urls.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url,
          key: ValueKey<String>(url),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          loadingBuilder:
              (BuildContext context, Widget child, ImageChunkEvent? progress) {
                if (progress == null) return child;

                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        scheme.surfaceContainerHigh,
                        scheme.surfaceContainerHighest,
                      ],
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                );
              },
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                return ColoredBox(
                  color: scheme.errorContainer,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                );
              },
        ),
      ),
    );
  }
}
