import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/photo.dart';
import 'order_service.dart';

/// Sappan share link (owner 26-Oct-2026). The cloud page shows the saree
/// (WhatsApp preview included), opens the app on it when installed, else the
/// App Store / Play Store.
const String kShareBase = 'https://asia-south1-akn-chat-a7dd8.cloudfunctions.net/spShare';

String shareLinkFor(Photo p) => '$kShareBase?d=${Uri.encodeComponent(p.id)}';

Future<void> shareSaree(BuildContext context, Photo p) async {
  final price = p.price == null ? '' : ' · ${OrderService.formatRupees(p.price!)}';
  final text = 'Sappan Sarees$price\n${shareLinkFor(p)}';
  final box = context.findRenderObject() as RenderBox?;
  await Share.share(
    text,
    subject: 'Sappan Sarees',
    // iPad needs an anchor for the share sheet.
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  );
}
