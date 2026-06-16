import 'dart:developer' as developer;

/// Simple performance wrapper to log timing of code blocks.
class PerformanceWrapper {
  final String name;
  final Stopwatch _stopwatch;

  PerformanceWrapper(this.name) : _stopwatch = Stopwatch() {
    _stopwatch.start();
    developer.log('Performance: [$name] started');
  }

  void stop() {
    _stopwatch.stop();
    developer.log('Performance: [$name] completed in ${_stopwatch.elapsedMilliseconds} ms');
  }
}

/// Convenience helper to measure async functions.
Future<T> measureAsync<T>(String name, Future<T> Function() function) async {
  final wrapper = PerformanceWrapper(name);
  try {
    return await function();
  } finally {
    wrapper.stop();
  }
}
