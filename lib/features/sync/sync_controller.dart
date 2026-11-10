import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/prefs/user_prefs_controller.dart';
import '../auth/auth_controller.dart';
import '../favorites/favorites_providers.dart';
import 'account_api.dart';
import 'sync_state.dart';

enum SyncPhase { idle, syncing, synced, failed }

class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.lastSyncedAt,
    this.message,
  });

  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? message;
}

const String _offlineMessage = 'Offline: changes will sync later.';
const String _expiredMessage = 'Your session expired. Please sign in again.';

/// Keeps favorites and settings in step with the signed-in account.
class SyncController extends Notifier<SyncStatus> {
  bool _running = false;

  @override
  SyncStatus build() => const SyncStatus();

  void reset() => _set(const SyncStatus());

  void _set(SyncStatus status) {
    if (ref.mounted) state = status;
  }

  /// Full sync. [pushPrefs] sends this device's settings (used after creating
  /// an account); otherwise the account's settings are used unless this device
  /// has unsent changes.
  Future<void> syncNow({bool pushPrefs = false}) async {
    final session = ref.read(currentSessionProvider);
    if (session == null || _running) return;
    _running = true;
    final lastSynced = state.lastSyncedAt;
    _set(SyncStatus(phase: SyncPhase.syncing, lastSyncedAt: lastSynced));
    try {
      final api = ref.read(accountApiProvider);
      final store = ref.read(syncStateRepositoryProvider);
      final pending = store.load();

      // Favorites: apply removals made offline, then merge this device's list.
      for (final id in pending.pendingRemoves) {
        await api.removeFavorite(session.token, id);
      }
      final device = ref
          .read(favoritesProvider)
          .where((id) => !pending.pendingRemoves.contains(id))
          .toList();
      final merged = await api.mergeFavorites(session.token, device);
      await ref.read(favoritesProvider.notifier).replaceAll(merged);

      // Settings: unsent local changes win; otherwise the account's are used.
      if (pushPrefs || pending.prefsDirty) {
        await api.updatePreferences(session.token, ref.read(userPrefsProvider));
      } else {
        final remote = await api.fetchPreferences(session.token);
        await ref.read(userPrefsProvider.notifier).applyRemote(remote);
      }

      await store.save(const SyncState());
      _set(SyncStatus(phase: SyncPhase.synced, lastSyncedAt: DateTime.now()));
    } on ApiException catch (error) {
      await _handleFailure(error, lastSynced);
    } catch (_) {
      _set(SyncStatus(
        phase: SyncPhase.failed,
        lastSyncedAt: lastSynced,
        message: 'Sync failed. Try again later.',
      ));
    } finally {
      _running = false;
    }
  }

  /// Sends one favorite change. If it fails, a removal is queued for later
  /// (additions are picked up by the next merge).
  Future<void> pushFavorite(String quoteId, {required bool added}) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;
    try {
      final store = ref.read(syncStateRepositoryProvider);
      final api = ref.read(accountApiProvider);
      try {
        if (added) {
          await api.addFavorite(session.token, quoteId);
        } else {
          await api.removeFavorite(session.token, quoteId);
        }
        final pending = store.load();
        if (pending.pendingRemoves.contains(quoteId)) {
          await store.save(pending.copyWith(
            pendingRemoves: {...pending.pendingRemoves}..remove(quoteId),
          ));
        }
      } on ApiException catch (error) {
        if (!error.isUnauthorized) {
          final pending = store.load();
          final removes = {...pending.pendingRemoves};
          if (added) {
            removes.remove(quoteId);
          } else {
            removes.add(quoteId);
          }
          await store.save(pending.copyWith(pendingRemoves: removes));
        }
        await _handleFailure(error, state.lastSyncedAt);
      }
    } catch (_) {
      // Storage unavailable or app closing: nothing more to do.
    }
  }

  /// Sends the current settings. They stay marked as unsent until it works.
  Future<void> onPrefsChanged() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;
    try {
      final store = ref.read(syncStateRepositoryProvider);
      await store.save(store.load().copyWith(prefsDirty: true));
      try {
        await ref
            .read(accountApiProvider)
            .updatePreferences(session.token, ref.read(userPrefsProvider));
        await store.save(store.load().copyWith(prefsDirty: false));
      } on ApiException catch (error) {
        await _handleFailure(error, state.lastSyncedAt);
      }
    } catch (_) {
      // Storage unavailable or app closing: nothing more to do.
    }
  }

  Future<void> _handleFailure(ApiException error, DateTime? lastSynced) async {
    if (!ref.mounted) return;
    if (error.isUnauthorized) {
      await ref.read(authControllerProvider.notifier).signOut();
      _set(const SyncStatus(phase: SyncPhase.failed, message: _expiredMessage));
      return;
    }
    _set(SyncStatus(
      phase: SyncPhase.failed,
      lastSyncedAt: lastSynced,
      message: error.isNetworkError ? _offlineMessage : error.message,
    ));
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncStatus>(SyncController.new);
