import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Own the connection until the entire response arrives, including its body.
Future<http.Response> timedHttp(
  String stage,
  Duration limit,
  Future<http.Response> Function(http.Client) send,
) async {
  final client = http.Client();
  try {
    return await send(client).timeout(limit);
  } on TimeoutException {
    throw TimeoutException(
      '$stage timed out after ${limit.inSeconds} seconds. Check your connection and try again.',
    );
  } finally {
    client.close();
  }
}

class ImportRateLimit implements Exception {
  final Duration? wait;
  const ImportRateLimit(this.wait);

  static Duration? parseWait(String? header) {
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
    try {
      final remaining = HttpDate.parse(header)
          .difference(DateTime.now().toUtc());
      return remaining.isNegative ? Duration.zero : remaining;
    } on HttpException {
      return null;
    } on FormatException {
      return null;
    }
  }
}

/// Retry the current import step only. Never use this for inventory writes.
Future<T> importStep<T>(
  String label,
  Future<T> Function(String attemptLabel) task, {
  void Function(String)? report,
  bool Function()? active,
  Duration retryDelay = const Duration(seconds: 1),
}) async {
  for (var attempt = 1; ; attempt++) {
    if (active?.call() == false) throw StateError('Import closed.');
    final status = '$label · attempt $attempt of 3';
    report?.call(status);
    try {
      return await task(status);
    } on ImportRateLimit catch (e) {
      final wait = e.wait ?? Duration(seconds: 15 * attempt);
      final seconds = (wait.inMilliseconds / 1000).ceil();
      if (attempt == 3 || wait > const Duration(minutes: 3)) {
        throw FormatException(
          'Kimi rate limit (HTTP 429) during $label. Retry in ${seconds > 0 ? seconds : 1} seconds. Your invoice is still selected.',
        );
      }
      for (var left = seconds; left > 0; left--) {
        if (active?.call() == false) throw StateError('Import closed.');
        report?.call('Kimi rate limit · retrying $label in ${left}s');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } on TimeoutException {
      if (attempt == 3)
        throw TimeoutException(
          '$label timed out on all three attempts. Your invoice is available to retry.',
        );
      report?.call('$label timed out. Retrying…');
      await Future<void>.delayed(retryDelay * attempt);
    }
  }
}
