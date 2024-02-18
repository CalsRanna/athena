import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

mixin Api {
  final String model = 'gpt-4-0125-preview';
  final String baseUrl = 'https://api.aiproxy.io/v1';

  Future<String> _getKey() async {
    final bytes = await rootBundle.load('asset/aiproxy.key');
    return utf8.decode(bytes.buffer.asUint8List());
  }

  Future<Stream<String>> request({
    required Map<String, dynamic> body,
    required String method,
    required String url,
  }) async {
    final client = http.Client();
    final uri = Uri.parse('$baseUrl$url');
    final key = await _getKey();
    final header = {
      "Content-Type": 'application/json',
      "Authorization": 'Bearer $key'
    };
    var request = http.Request('post', uri);
    request.headers.addAll(header);
    request.body = json.encode(body);
    final controller = StreamController<String>();
    final response = await client.send(request);
    response.stream.listen((codeUnits) {
      var decodedMessage = utf8.decode(codeUnits).replaceAll('[DONE]', '');
      final patterns = decodedMessage.split('data:');
      for (var pattern in patterns) {
        pattern = pattern.trim();
        if (pattern.isNotEmpty) {
          final data = json.decode(pattern);
          if (data['error'] != null) {
            final error = data['error'];
            controller.add('[${error['type']}]:${error['message']}');
          } else {
            final delta = data['choices'][0]['delta'];
            controller.add(delta['content'] ?? '');
          }
        }
      }
    }, onDone: () {
      client.close();
      controller.close();
    });
    return controller.stream;
  }
}
