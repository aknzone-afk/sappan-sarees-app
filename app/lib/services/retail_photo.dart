import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../config.dart';
import 'price_markup.dart';

/// Sappan retail (owner 25-Oct-2026): the shop's photos carry the WHOLESALE
/// price printed in a white "Rs 545/-" box. Every photo this app SHOWS is
/// downloaded through [RetailPhotoFileService], which erases that price and
/// prints "Rs <price × kRetailMultiplier>/-" in its place (the same proven
/// [PriceMarkup] used for customer re-pricing on share). The cached file is
/// the repainted one, so grid, viewer, pick screen and cart all show the
/// retail price. Price READING uses a separate raw cache (see price_ocr.dart),
/// so the stored price stays wholesale and is doubled exactly once.
class RetailPhotoFileService extends FileService {
  final HttpFileService _http = HttpFileService();
  static final PriceMarkup _markup = PriceMarkup();

  /// ML Kit + canvas work one photo at a time (memory on a fresh install).
  static Future<void> _tail = Future.value();

  static Future<T> _oneAtATime<T>(Future<T> Function() task) {
    final run = _tail.then((_) => task());
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  RetailPhotoFileService() {
    concurrentFetches = 8;
  }

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    final res = await _http.get(url, headers: headers);
    if (res.statusCode != 200 || !url.contains('drive.google.com/thumbnail')) return res;
    final chunks = <int>[];
    await for (final c in res.content) {
      chunks.addAll(c);
    }
    final raw = Uint8List.fromList(chunks);
    final out = await _oneAtATime(() => repaint(raw, url.hashCode.toString()));
    return _BytesResponse(res, out);
  }

  /// [bytes] with its printed price replaced by the retail price (JPEG).
  /// The original bytes when no printed price is found or anything fails.
  static Future<Uint8List> repaint(Uint8List bytes, String key) async {
    try {
      final png = await _markup.apply(
        imageBytes: bytes,
        knownPrice: 0,
        percent: (kRetailMultiplier - 1) * 100.0,
        tmpKey: 'rp_$key',
        roundTo5: false, // exactly 2 × the printed price
      );
      if (identical(png, bytes)) return bytes;
      // Never upscales (scale = max(1, …)); keeps the photo's own size.
      final jpg = await FlutterImageCompress.compressWithList(png,
          quality: 90, minWidth: 10000, minHeight: 10000, format: CompressFormat.jpeg);
      return jpg.isEmpty ? png : jpg;
    } catch (_) {
      return bytes;
    }
  }
}

class _BytesResponse implements FileServiceResponse {
  final FileServiceResponse _inner;
  final Uint8List _bytes;
  _BytesResponse(this._inner, this._bytes);

  @override
  Stream<List<int>> get content => Stream.value(_bytes);
  @override
  int? get contentLength => _bytes.length;
  @override
  int get statusCode => _inner.statusCode;
  @override
  DateTime get validTill => _inner.validTill;
  @override
  String? get eTag => _inner.eTag;
  @override
  String get fileExtension => '.jpg';
}
