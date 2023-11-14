import 'dart:async';
import 'dart:convert';

import 'package:athena/schema/chat.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ChatApi {
  final String model = 'gpt-4-1106-preview';
  final String url = 'https://api.aiproxy.io/v1';
  Future<Stream<String>> getCompletion({required List<Message> messages}) {
    return _request(messages: messages);
  }

  Future<Stream<String>> getTitle({required String value}) {
    const String prompt = '请使用四到五个字描述上面这句话的简要主题，而不是回答这句话提及到的问题。'
        '不要解释、不要标点符号、不要语气助词、不要多余文本。'
        '如果没有主题，请直接返回“随便聊聊”。';
    return _request(messages: [
      Message()
        ..content = value
        ..role = 'user',
      Message()
        ..content = prompt
        ..role = 'user'
    ]);
  }

  Future<String> _getKey() async {
    final bytes = await rootBundle.load('asset/aiproxy.key');
    return utf8.decode(bytes.buffer.asUint8List());
  }

  Future<Stream<String>> _request({
    required List<Message> messages,
  }) async {
    final key = await _getKey();
    final client = http.Client();
    final uri = Uri.parse('$url/chat/completions');
    final header = {
      "Content-Type": 'application/json',
      "Authorization": 'Bearer $key'
    };
    final body = {"model": model, "messages": messages, "stream": true};
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
