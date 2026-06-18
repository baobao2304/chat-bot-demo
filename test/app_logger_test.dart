import 'dart:async';

import 'package:chatbotdemo/core/logging/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wraps each log event in borders and adds a blank separator', () {
    final output = <String>[];
    final previousEnabled = AppLogger.enabled;
    AppLogger.enabled = true;
    addTearDown(() => AppLogger.enabled = previousEnabled);

    runZoned(
      () => AppLogger.info('LoggerTest', 'readable event'),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => output.add(line),
      ),
    );

    expect(output.first, startsWith('+==================== CHATBOT_LOG #'));
    expect(output, contains(contains('tag=LoggerTest')));
    expect(output[output.length - 2], startsWith('+--------------------'));
    expect(output.last, isEmpty);
  });
}
