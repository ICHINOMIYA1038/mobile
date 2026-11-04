import 'dart:async';
import 'dart:convert';

import '../lib/src/sse.dart';

Future<void> main() async {
  final bytes = utf8.encode(
    'data: {"type":"text","delta":"答"}\r\n\r\n'
    'data: {"type":"text","delta":"え"}\n\n'
    'data: {"type":"done"}\n\n',
  );
  final chunks = <List<int>>[
    for (var i = 0; i < bytes.length; i += 3)
      bytes.sublist(i, i + 3 > bytes.length ? bytes.length : i + 3),
  ];
  final events = await decodeSse(Stream.fromIterable(chunks)).toList();
  final text = events
      .where((event) => event['type'] == 'text')
      .map((event) => event['delta'])
      .join();
  if (text != '答え' || events.last['type'] != 'done') {
    throw StateError('SSE の分割された返答を正しく読み取れません');
  }
}
