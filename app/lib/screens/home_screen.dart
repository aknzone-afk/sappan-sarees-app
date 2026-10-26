import 'dart:async';

import 'package:catalog_app/widgets/caps_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/folder.dart';
import '../models/photo.dart';
import '../providers/providers.dart';
import '../services/drive_urls.dart';
import '../services/order_service.dart';
import '../services/photo_freshness.dart';
import '../theme.dart';
import 'retail_signup_screen.dart' show HeritageWeaves, HouseCrafts;
import '../widgets/loading_collage.dart';

/// SAPPAN SAREES home — a fashion-house storefront (owner 25-Oct-2026: "like
/// Gucci / Armani, nobody may tell it is the B.B Synthetics app"): centred
/// tracked wordmark, full-bleed editorial hero, New In rail, full-bleed
/// collection tiles, the weaves of India, the house promises, and a bottom
/// navigation bar (Home · New In · Search · Bag · Orders).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Warm every folder's cover in the background (once per launch).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (context.mounted) warmAllFolderCovers(ref); // screen may be gone by now
      });
    });
    final catalogAsync = ref.watch(catalogProvider);

    // First-install loading: fullscreen collage with no app bar / nav bar.
    if (catalogAsync.value == null && !catalogAsync.hasError) {
      return const Scaffold(body: LoadingCollage());
    }
    if (catalogAsync.hasValue && ref.watch(firstScreensWarmProvider).isLoading) {
      return const Scaffold(body: LoadingCollage());
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'The House',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _showShopInfo(context),
        ),
        title: GestureDetector(
          onTap: () => _showShopInfo(context),
          child: const _Wordmark(),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
          ),
          const _BagIcon(),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: kMaroon,
        onRefresh: () async {
          // The app-wide container survives a rebuild during the await.
          final c = ProviderScope.containerOf(context, listen: false);
          await c.read(pullToRefreshProvider)();
          await c.read(catalogProvider.future);
        },
        child: _buildBody(ref, catalogAsync),
      ),
      bottomNavigationBar: const SappanNavBar(current: 0),
    );
  }

  Widget _buildBody(WidgetRef ref, AsyncValue<dynamic> async) {
    final value = async.value;
    if (value == null) {
      if (async.hasError) {
        return _ErrorView(
          message: async.error.toString(),
          onRetry: () => ref.invalidate(catalogProvider),
        );
      }
      return const LoadingCollage();
    }
    final data = value as dynamic;
    if (data.photos.isEmpty) return const _EmptyCatalogView();
    return const _Storefront();
  }
}

/// Centred, widely tracked serif wordmark.
class _Wordmark extends StatelessWidget {
  const _Wordmark();
  @override
  Widget build(BuildContext context) {
    return const Column(mainAxisSize: MainAxisSize.min, children: [
      Text('SAPPAN',
          style: TextStyle(
              fontFamily: 'Playfair',
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: 9,
              height: 1.0,
              color: kMaroon)),
      SizedBox(height: 4),
      Text('S A R E E S',
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, letterSpacing: 4.5, color: kGold, height: 1.0)),
    ]);
  }
}

class _BagIcon extends ConsumerWidget {
  const _BagIcon();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(favoritesProvider).length;
    return IconButton(
      tooltip: 'Shopping Bag',
      onPressed: () => context.push('/favorites'),
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text('$n'),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}

/// Bottom navigation shared by the storefront screens.
class SappanNavBar extends ConsumerWidget {
  final int current;
  const SappanNavBar({super.key, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bag = ref.watch(favoritesProvider).length;
    Widget badge(int n, IconData icon) =>
        Badge(isLabelVisible: n > 0, label: Text('$n'), child: Icon(icon));
    return NavigationBar(
      selectedIndex: current,
      onDestinationSelected: (i) {
        if (i == current) return;
        switch (i) {
          case 0:
            context.go('/');
          case 1:
            context.push('/new');
          case 2:
            context.push('/search');
          case 3:
            context.push('/favorites');
          case 4:
            context.push('/orders');
        }
      },
      destinations: [
        const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'HOME'),
        const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'NEW IN'),
        const NavigationDestination(icon: Icon(Icons.search_rounded), label: 'SEARCH'),
        NavigationDestination(icon: badge(bag, Icons.shopping_bag_outlined), label: 'BAG'),
        const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'ORDERS'),
      ],
    );
  }
}

class _Storefront extends ConsumerWidget {
  const _Storefront();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(topLevelFoldersProvider);
    final photos = [...ref.watch(photosProvider)]..sort(Photo.compareNewestFirst);
    final hero = photos.take(6).toList();
    final newIn = photos.take(14).toList();
    final w = MediaQuery.sizeOf(context).width;

    return CustomScrollView(
      slivers: [
        if (hero.isNotEmpty) SliverToBoxAdapter(child: _Hero(photos: hero, height: w * 1.12)),
        const SliverToBoxAdapter(child: _SectionHead(eyebrow: 'JUST ARRIVED', title: 'New In', route: '/new')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 262,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: newIn.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _ProductTile(photo: newIn[i], ids: [for (final p in newIn) p.id]),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: _SectionHead(eyebrow: 'THE HOUSE EDIT', title: 'Collections')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          sliver: SliverGrid.builder(
            itemCount: folders.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.70,
            ),
            itemBuilder: (context, i) => CollectionTile(folder: folders[i]),
          ),
        ),
        const SliverToBoxAdapter(child: _WeavesBand()),
        const SliverToBoxAdapter(child: _Promises()),
        const SliverToBoxAdapter(child: _Footer()),
      ],
    );
  }
}

/// Full-bleed editorial hero: the newest designs, gently cross-fading.
class _Hero extends StatefulWidget {
  final List<Photo> photos;
  final double height;
  const _Hero({required this.photos, required this.height});
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _page = PageController();
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_page.hasClients || widget.photos.length < 2) return;
      _i = (_i + 1) % widget.photos.length;
      _page.animateToPage(_i, duration: const Duration(milliseconds: 900), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(fit: StackFit.expand, children: [
        PageView.builder(
          controller: _page,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: widget.photos[i].thumbUrl(),
            cacheManager: photoCacheManager,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter, // the saree, not its label
            placeholder: (_, __) => Container(color: kLinen),
            errorWidget: (_, __, ___) => Container(color: kLinen),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.30, 0.62, 0.80],
                colors: [Color(0x00000000), Color(0xCC2A0710), Color(0xFF2A0710)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 28,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('THE NEW SEASON',
                style: TextStyle(color: kGoldSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 4)),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: Text(kHeroLines[_i % kHeroLines.length],
                  key: ValueKey(_i % kHeroLines.length),
                  style: const TextStyle(
                      fontFamily: 'Playfair', color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, height: 1.12)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1),
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                ),
                onPressed: () => context.push('/new'),
                child: const Text('DISCOVER', style: TextStyle(letterSpacing: 3.5, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              for (var k = 0; k < widget.photos.length; k++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(left: 6),
                  width: k == _i ? 18 : 6,
                  height: 2,
                  color: k == _i ? kGold : Colors.white54,
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _SectionHead extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? route;
  const _SectionHead({required this.eyebrow, required this.title, this.route});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 34, 18, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(eyebrow, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 3.6, color: kGold)),
            const SizedBox(height: 6),
            Text(title,
                style: const TextStyle(fontFamily: 'Playfair', fontSize: 27, fontWeight: FontWeight.w700, color: kMaroon, height: 1.05)),
          ]),
        ),
        if (route != null)
          TextButton(
            onPressed: () => context.push(route!),
            child: const Text('VIEW ALL', style: TextStyle(letterSpacing: 2.4, fontSize: 11.5)),
          ),
      ]),
    );
  }
}

/// New-In product: portrait photo, design and price set like a price card.
class _ProductTile extends StatelessWidget {
  final Photo photo;
  final List<String> ids;
  const _ProductTile({required this.photo, required this.ids});
  @override
  Widget build(BuildContext context) {
    final price = photo.price;
    return SizedBox(
      width: 158,
      child: InkWell(
        onTap: () => context.push('/photo/${Uri.encodeComponent(photo.id)}', extra: ids),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 198,
            width: 158,
            child: CachedNetworkImage(
              imageUrl: photo.thumbUrl(),
              cacheManager: photoCacheManager,
              memCacheWidth: gridDecodeWidth(context),
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: kLinen),
              errorWidget: (_, __, ___) => Container(color: kLinen),
            ),
          ),
          const SizedBox(height: 10),
          if (price != null)
            Text(OrderService.formatRupees(price),
                style: const TextStyle(fontFamily: 'Playfair', fontSize: 17, fontWeight: FontWeight.w700, color: kMaroon)),
        ]),
      ),
    );
  }
}

/// A collection: full-bleed cover, name in white serif over a wine veil.
class CollectionTile extends StatelessWidget {
  final CatalogFolder folder;
  const CollectionTile({super.key, required this.folder});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/folder/${Uri.encodeComponent(folder.path.isEmpty ? "_root" : folder.path)}'),
      child: Stack(fit: StackFit.expand, children: [
        if (folder.coverThumbPath != null)
          CachedNetworkImage(
            imageUrl: DriveUrls.thumbnail(folder.coverThumbPath!, width: kThumbnailWidth),
            cacheManager: photoCacheManager,
            memCacheWidth: gridDecodeWidth(context),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter, // the saree, not its label
            placeholder: (_, __) => Container(color: kLinen),
            errorWidget: (_, __, ___) => Container(color: kLinen),
          )
        else
          Container(color: kLinen),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.42, 0.66, 0.80],
              colors: [Color(0x00000000), Color(0xD92A0710), Color(0xFF2A0710)],
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 14,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              folder.path.isEmpty ? 'The Collection' : _titleCase(folder.displayName),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Playfair', color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w700, height: 1.15),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Container(width: 18, height: 1, color: kGold),
              const SizedBox(width: 8),
              Text('${folder.photoCount} DESIGNS',
                  style: const TextStyle(color: kGoldSoft, fontSize: 9.5, letterSpacing: 2.4, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

String _titleCase(String s) => s
    .toLowerCase()
    .split(' ')
    .map((w) => w.isEmpty ? w : (RegExp(r'^rs$').hasMatch(w) ? 'Rs' : w[0].toUpperCase() + w.substring(1)))
    .join(' ');

class _WeavesBand extends StatelessWidget {
  const _WeavesBand();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.fromLTRB(18, 34, 18, 30),
      color: kLinen,
      child: const Column(children: [
        Text('THE ATELIER',
            style: TextStyle(fontSize: 10.5, letterSpacing: 3.6, fontWeight: FontWeight.w700, color: kGold)),
        SizedBox(height: 8),
        Text('Crafted by Hand,\nFinished in Gold',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Playfair', fontSize: 27, fontWeight: FontWeight.w700, color: kMaroon, height: 1.15)),
        SizedBox(height: 10),
        Text(
          'Every Sappan saree carries hours of craft — zari woven into the pallu, embroidery on every '
          'inch, crystals set one by one. These are the arts our collection is made of.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.6, color: kInk),
        ),
        SizedBox(height: 22),
        HouseCrafts(),
        SizedBox(height: 22),
        Text('A JOURNEY ACROSS INDIA',
            style: TextStyle(fontSize: 10.5, letterSpacing: 3.6, fontWeight: FontWeight.w700, color: kGold)),
        SizedBox(height: 8),
        Text('Inspired by the great weaving traditions of every region.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.5, color: kInk)),
        SizedBox(height: 16),
        HeritageWeaves(),
      ]),
    );
  }
}

class _Promises extends StatelessWidget {
  const _Promises();
  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, String s) => Expanded(
          child: Column(children: [
            Icon(i, color: kMaroon, size: 26),
            const SizedBox(height: 10),
            Text(t,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, letterSpacing: 2, fontWeight: FontWeight.w700, color: kInk)),
            const SizedBox(height: 4),
            Text(s, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF6B5E57))),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 34, 14, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        item(Icons.local_shipping_outlined, 'ACROSS INDIA', 'Delivered to your door'),
        item(Icons.diamond_outlined, 'FROM ONE SAREE', 'No minimum order'),
        item(Icons.verified_outlined, 'CURATED QUALITY', 'Every order checked by hand'),
      ]),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 40),
      child: Column(children: [
        Container(height: 0.8, color: kHairline),
        const SizedBox(height: 26),
        const _Wordmark(),
        const SizedBox(height: 10),
        const Text('© 2026 SAPPAN SAREES · INDIA',
            style: TextStyle(fontSize: 9.5, letterSpacing: 2.4, color: Color(0xFF8A7B70))),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off_rounded, size: 56, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text('We could not reach the collection. Please check your internet.',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        Center(child: OutlinedButton(onPressed: onRetry, child: const Text('TRY AGAIN'))),
      ],
    );
  }
}

/// "The House" card (menu / wordmark tap): the brand story + contact.
void _showShopInfo(BuildContext context) {
  Future<void> openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {/* no app can open it */}
  }

  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Center(child: _Wordmark()),
      contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'A house of luxury sarees, inspired by the great weaving traditions of India — '
            'delivered to your door, anywhere in the country.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.55),
          ),
          const SizedBox(height: 16),
          const HeritageWeaves(),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => openUrl(kPrivacyUrl),
            child: const Text('PRIVACY POLICY', style: TextStyle(fontSize: 11, letterSpacing: 1.6)),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const UText('Close')),
      ],
    ),
  );
}

class _EmptyCatalogView extends StatelessWidget {
  const _EmptyCatalogView();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        SizedBox(height: 120),
        Center(child: _Wordmark()),
        SizedBox(height: 20),
        Text('Our new collection is arriving shortly.',
            textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Playfair', fontSize: 18, color: kMaroon)),
      ],
    );
  }
}
