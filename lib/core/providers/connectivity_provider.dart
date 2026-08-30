import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live online/offline status (design.md §9: reads work offline, all
/// writes are blocked with a plain "connect to internet" prompt).
/// Emits the current status immediately, then follows changes.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  final current = await connectivity.checkConnectivity();
  yield current != ConnectivityResult.none;

  yield* connectivity.onConnectivityChanged.map(
    (result) => result != ConnectivityResult.none,
  );
});

/// One-off synchronous-ish check for write handlers that need to gate an
/// action right before firing it (in addition to the UI already being
/// disabled via isOnlineProvider — this is a second check against a race
/// where connectivity drops between render and tap).
Future<bool> isCurrentlyOnline() async {
  final result = await Connectivity().checkConnectivity();
  return result != ConnectivityResult.none;
}
