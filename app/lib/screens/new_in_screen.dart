import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/photo.dart';
import '../providers/providers.dart';
import '../theme.dart';
import '../widgets/photo_grid.dart';

/// NEW IN (owner 26-Oct-2026): simply the newest designs, newest first — no
/// day-by-day feed (that is the B.B Synthetics app's own feature).
class NewInScreen extends ConsumerWidget {
  const NewInScreen({super.key});

  static const kCount = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = [...ref.watch(photosProvider)]..sort(Photo.compareNewestFirst);
    final shown = photos.take(kCount).toList();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('NEW IN',
            style: TextStyle(fontFamily: 'Playfair', fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 2.4)),
      ),
      body: shown.isEmpty
          ? const Center(
              child: Text('The new collection is arriving shortly.',
                  style: TextStyle(fontFamily: 'Playfair', fontSize: 18, color: kMaroon)))
          : PhotoGrid(photos: shown, padding: const EdgeInsets.fromLTRB(12, 12, 12, 24)),
    );
  }
}
