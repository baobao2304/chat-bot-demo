import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static const _verboseLogsOverride = String.fromEnvironment(
    'CHATBOT_VERBOSE_LOGS',
  );
  static const _linePrefix = 'CHATBOT_LOG';
  static const _chunkSize = 700;

  static bool enabled = _resolveEnabled();
  static int _sequence = 0;

  static final Logger _logger = Logger(
    filter: _AppLogFilter(() => enabled),
    printer: _PlainAppLogPrinter(chunkSize: _chunkSize),
    output: _ChunkedConsoleOutput(chunkSize: _chunkSize),
  );

  static void trace(String tag, String message, [Object? data]) {
    _write(Level.trace, 'TRACE', tag, message, data: data);
  }

  static void debug(String tag, String message, [Object? data]) {
    _write(Level.debug, 'DEBUG', tag, message, data: data);
  }

  static void info(String tag, String message, [Object? data]) {
    _write(Level.info, 'INFO', tag, message, data: data);
  }

  static void step(String tag, String message, [Object? data]) {
    _write(Level.info, 'STEP', tag, message, data: data);
  }

  static void start(String tag, String message, [Object? data]) {
    _write(Level.info, 'START', tag, message, data: data);
  }

  static void success(String tag, String message, [Object? data]) {
    _write(Level.info, 'OK', tag, message, data: data);
  }

  static void command(String tag, String message, String command) {
    _write(Level.info, 'CURL', tag, message, rawLabel: 'curl', raw: command);
  }

  static void warning(
    String tag,
    String message, {
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _write(
      Level.warning,
      'WARN',
      tag,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void failure(
    String tag,
    String message, {
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _write(
      Level.error,
      'FAIL',
      tag,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String tag,
    String message, {
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    failure(tag, message, data: data, error: error, stackTrace: stackTrace);
  }

  static String compact(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is String) {
      return value;
    }
    try {
      return jsonEncode(_jsonSafe(value));
    } on Object {
      return value.toString();
    }
  }

  static void _write(
    Level level,
    String phase,
    String tag,
    String message, {
    Object? data,
    String? rawLabel,
    String? raw,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) {
      return;
    }

    _logger.log(
      level,
      _AppLogRecord(
        sequence: ++_sequence,
        phase: phase,
        tag: tag,
        message: message,
        data: data,
        rawLabel: rawLabel,
        raw: raw,
      ),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Object? _jsonSafe(Object? value) {
    if (value == null ||
        value is num ||
        value is bool ||
        value is String ||
        value is DateTime) {
      return value is DateTime ? value.toIso8601String() : value;
    }
    if (value is Uri) {
      return value.toString();
    }
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          if (entry.key != null) entry.key.toString(): _jsonSafe(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    return value.toString();
  }

  static bool _resolveEnabled() {
    final normalized = _verboseLogsOverride.trim().toLowerCase();
    if (normalized.isEmpty) {
      return !kReleaseMode;
    }
    return switch (normalized) {
      'true' || '1' || 'yes' || 'y' || 'on' => true,
      'false' || '0' || 'no' || 'n' || 'off' => false,
      _ => !kReleaseMode,
    };
  }
}

class _AppLogRecord {
  const _AppLogRecord({
    required this.sequence,
    required this.phase,
    required this.tag,
    required this.message,
    this.data,
    this.rawLabel,
    this.raw,
  });

  final int sequence;
  final String phase;
  final String tag;
  final String message;
  final Object? data;
  final String? rawLabel;
  final String? raw;
}

class _PlainAppLogPrinter extends LogPrinter {
  _PlainAppLogPrinter({required this.chunkSize});

  final int chunkSize;

  @override
  List<String> log(LogEvent event) {
    final record = event.message;
    if (record is! _AppLogRecord) {
      return <String>[
        _formatBaseLine(
          event: event,
          sequence: 0,
          phase: 'LOG',
          tag: 'AppLogger',
          message: record.toString(),
        ),
      ];
    }

    final base = _formatBaseLine(
      event: event,
      sequence: record.sequence,
      phase: record.phase,
      tag: record.tag,
      message: record.message,
    );
    final lines = <String>[base];

    if (record.data != null) {
      lines.addAll(
        _formatPartLines(
          sequence: record.sequence,
          part: 'DATA',
          value: AppLogger.compact(record.data),
        ),
      );
    }

    if (record.raw != null && record.rawLabel != null) {
      lines.addAll(
        _formatPartLines(
          sequence: record.sequence,
          part: record.rawLabel!.toUpperCase(),
          value: record.raw!,
        ),
      );
    }

    if (event.error != null) {
      lines.addAll(
        _formatPartLines(
          sequence: record.sequence,
          part: 'ERROR',
          value: event.error.toString(),
        ),
      );
    }

    if (event.stackTrace != null) {
      lines.addAll(
        _formatPartLines(
          sequence: record.sequence,
          part: 'STACK',
          value: event.stackTrace.toString(),
        ),
      );
    }

    return lines;
  }

  String _formatBaseLine({
    required LogEvent event,
    required int sequence,
    required String phase,
    required String tag,
    required String message,
  }) {
    return [
      AppLogger._linePrefix,
      'seq=${sequence.toString().padLeft(5, '0')}',
      'part=HEAD',
      'time=${event.time.toIso8601String()}',
      'level=${event.level.name.toUpperCase()}',
      'phase=$phase',
      'tag=$tag',
      'msg=${_quote(message)}',
    ].join(' ');
  }

  List<String> _formatPartLines({
    required int sequence,
    required String part,
    required String value,
  }) {
    final safeValue = _singleLine(value);
    final chunks = <String>[];
    if (safeValue.isEmpty) {
      chunks.add('');
    } else {
      for (var index = 0; index < safeValue.length; index += chunkSize) {
        final end = (index + chunkSize > safeValue.length)
            ? safeValue.length
            : index + chunkSize;
        chunks.add(safeValue.substring(index, end));
      }
    }

    final total = chunks.length;
    return <String>[
      for (var index = 0; index < chunks.length; index++)
        [
          AppLogger._linePrefix,
          'seq=${sequence.toString().padLeft(5, '0')}',
          'part=$part',
          'chunk=${index + 1}/$total',
          'value=${chunks[index]}',
        ].join(' '),
    ];
  }

  String _quote(String value) {
    return jsonEncode(value);
  }

  String _singleLine(String value) {
    return value
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n')
        .replaceAll('\t', r'\t');
  }
}

class _ChunkedConsoleOutput extends LogOutput {
  _ChunkedConsoleOutput({required this.chunkSize});

  final int chunkSize;

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      if (line.length <= chunkSize * 2) {
        // ignore: avoid_print
        print(line);
        continue;
      }

      for (var index = 0; index < line.length; index += chunkSize) {
        final end = (index + chunkSize > line.length)
            ? line.length
            : index + chunkSize;
        // ignore: avoid_print
        print(line.substring(index, end));
      }
    }
  }
}

class _AppLogFilter extends LogFilter {
  _AppLogFilter(this.isEnabled);

  final bool Function() isEnabled;

  @override
  bool shouldLog(LogEvent event) {
    final minimumLevel = level ?? Logger.level;
    return isEnabled() && event.level >= minimumLevel;
  }
}
