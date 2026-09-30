import 'dart:async';

class ProbeCancelled implements Exception {
  const ProbeCancelled();
}

class CancellationToken {
  final _cancelled = Completer<void>();
  final List<void Function()> _cleanup = [];
  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;
  void check() {
    if (isCancelled) throw const ProbeCancelled();
  }

  void Function() onCancel(void Function() action) {
    if (isCancelled) {
      action();
    } else {
      _cleanup.add(action);
    }
    return () {
      _cleanup.remove(action);
    };
  }

  void cancel() {
    if (isCancelled) return;
    _cancelled.complete();
    for (final action in _cleanup) {
      try {
        action();
      } catch (_) {}
    }
    _cleanup.clear();
  }

  Future<T> bind<T>(Future<T> operation) => Future.any([
    operation,
    whenCancelled.then<T>((_) => throw const ProbeCancelled()),
  ]);
}
