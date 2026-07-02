import 'package:flutter/foundation.dart';

/// Tracks whether cloud sync is failing during an active round.
class SyncStatusNotifier extends ChangeNotifier {
  SyncStatusNotifier._();
  static final SyncStatusNotifier instance = SyncStatusNotifier._();

  bool _syncFailing = false;
  String? _message;

  bool get syncFailing => _syncFailing;
  String? get message => _message;

  void recordFailure([String? detail]) {
    final next = true;
    final msg = detail ?? 'Cloud sync is failing. Scores are saved on this device.';
    if (_syncFailing && _message == msg) return;
    _syncFailing = next;
    _message = msg;
    notifyListeners();
  }

  void recordSuccess() {
    if (!_syncFailing) return;
    _syncFailing = false;
    _message = null;
    notifyListeners();
  }
}
