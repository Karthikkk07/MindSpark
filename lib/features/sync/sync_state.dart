import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/prefs/user_prefs_controller.dart';

/// What still has to be sent to the account.
class SyncState {
  const SyncState({
    this.prefsDirty = false,
    this.pendingRemoves = const <String>{},
  });

  /// Settings changed on this device that the account has not received.
  final bool prefsDirty;

  /// Favorites removed while offline; the account still has them.
  final Set<String> pendingRemoves;

  SyncState copyWith({bool? prefsDirty, Set<String>? pendingRemoves}) {
    return SyncState(
      prefsDirty: prefsDirty ?? this.prefsDirty,
      pendingRemoves: pendingRemoves ?? this.pendingRemoves,
    );
  }
}

class SyncStateRepository {
  SyncStateRepository(this._prefs);

  final SharedPreferences _prefs;

  static const keyPrefsDirty = 'sync_prefs_dirty';
  static const keyPendingRemoves = 'sync_pending_removes';

  SyncState load() {
    return SyncState(
      prefsDirty: _prefs.getBool(keyPrefsDirty) ?? false,
      pendingRemoves:
          (_prefs.getStringList(keyPendingRemoves) ?? const <String>[]).toSet(),
    );
  }

  Future<void> save(SyncState state) async {
    await _prefs.setBool(keyPrefsDirty, state.prefsDirty);
    await _prefs.setStringList(
      keyPendingRemoves,
      state.pendingRemoves.toList()..sort(),
    );
  }
}

final syncStateRepositoryProvider = Provider<SyncStateRepository>(
  (ref) => SyncStateRepository(ref.watch(sharedPreferencesProvider)),
);
