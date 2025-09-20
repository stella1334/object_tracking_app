import 'dart:ui';

class Throttler {
  DateTime _lastExecution = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration interval;

  Throttler({this.interval = const Duration(milliseconds: 500)});

  void run(VoidCallback action) {
    final now = DateTime.now();
    if (now.difference(_lastExecution) >= interval) {
      _lastExecution = now;
      action();
    }
  }
}
