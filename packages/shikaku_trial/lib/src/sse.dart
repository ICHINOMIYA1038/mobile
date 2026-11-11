import 'dart:convert';

Stream<Map<String, dynamic>> decodeSse(Stream<List<int>> bytes) async* {
  var buffer = '';
  await for (final chunk in bytes.transform(utf8.decoder)) {
    buffer += chunk;
    buffer = buffer.replaceAll('\r\n', '\n');
    while (buffer.contains('\n\n')) {
      final end = buffer.indexOf('\n\n');
      final frame = buffer.substring(0, end);
      buffer = buffer.substring(end + 2);
      for (final line in frame.split('\n')) {
        if (!line.startsWith('data:')) continue;
        try {
          yield jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
        } catch (_) {}
      }
    }
  }
}
