import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/quote.dart';

/// Where quotes come from. Swappable: assets now, API plus cache later.
abstract class QuoteRepository {
  Future<List<Quote>> loadAll();
}

/// Reads the quotes bundled inside the app, so they work offline.
class AssetQuoteRepository implements QuoteRepository {
  AssetQuoteRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String assetPath = 'assets/data/quotes.json';

  final AssetBundle _bundle;

  @override
  Future<List<Quote>> loadAll() async {
    final raw = await _bundle.loadString(assetPath);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['quotes'] as List<dynamic>;
    return list
        .map((item) => Quote.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
