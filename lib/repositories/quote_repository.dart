import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../models/quote.dart';

/// The outcome of asking the server for the latest quotes.
enum QuoteRefresh { updated, unchanged, failed }

/// Where quotes come from.
abstract class QuoteRepository {
  /// The quotes to show right now. Never waits for the network.
  Future<List<Quote>> loadAll();
}

/// A repository that can also download the latest quotes from a server.
abstract class RefreshableQuoteRepository implements QuoteRepository {
  Future<QuoteRefresh> refresh();
}

extension QuoteRepositoryRefresh on QuoteRepository {
  /// Refreshes from the server when supported, otherwise does nothing.
  Future<QuoteRefresh> refreshIfSupported() {
    final self = this;
    return self is RefreshableQuoteRepository
        ? self.refresh()
        : Future.value(QuoteRefresh.unchanged);
  }
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

/// Quotes from the MindSpark API, saved on the device.
///
/// [loadAll] answers at once from the saved copy (or the bundled quotes the
/// first time), so the app starts fast and works offline. [refresh] then
/// downloads the latest list and saves it for next time.
class ApiQuoteRepository implements RefreshableQuoteRepository {
  ApiQuoteRepository({
    required ApiClient api,
    required SharedPreferences prefs,
    required QuoteRepository fallback,
  })  : _api = api,
        _prefs = prefs,
        _fallback = fallback;

  static const String cacheKey = 'quotes_cache_v1';
  static const int _pageSize = 50;
  static const int _maxPages = 20;

  final ApiClient _api;
  final SharedPreferences _prefs;
  final QuoteRepository _fallback;

  @override
  Future<List<Quote>> loadAll() async {
    final cached = _readCache();
    if (cached != null && cached.isNotEmpty) return cached;
    return _fallback.loadAll();
  }

  List<Quote>? _readCache() {
    final raw = _prefs.getString(cacheKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => Quote.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return null; // a damaged copy is ignored
    }
  }

  @override
  Future<QuoteRefresh> refresh() async {
    final List<Quote> fresh;
    try {
      fresh = await _download();
    } on ApiException {
      return QuoteRefresh.failed;
    } catch (_) {
      return QuoteRefresh.failed; // an unexpected reply is treated as offline
    }
    if (fresh.isEmpty) return QuoteRefresh.failed;

    final encoded = jsonEncode(fresh.map((quote) => quote.toJson()).toList());
    if (encoded == _prefs.getString(cacheKey)) return QuoteRefresh.unchanged;
    await _prefs.setString(cacheKey, encoded);
    return QuoteRefresh.updated;
  }

  Future<List<Quote>> _download() async {
    final quotes = <Quote>[];
    for (var page = 1; page <= _maxPages; page++) {
      final json = await _api.get('/quotes?limit=$_pageSize&page=$page');
      final data = (json['data'] as List<dynamic>?) ?? const [];
      quotes.addAll(
        data.map((item) => Quote.fromJson(item as Map<String, dynamic>)),
      );
      final totalPages = (json['totalPages'] as num?)?.toInt() ?? 1;
      if (page >= totalPages) break;
    }
    return quotes;
  }
}
