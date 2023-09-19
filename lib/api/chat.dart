import 'dart:async';
import 'dart:convert';

import 'package:athena/schema/chat.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ChatApi {
  Future<Stream<String>> getCompletion({
    required List<Message> messages,
    required String model,
  }) {
    return _request(messages: messages, model: model);
  }

  Future<Stream<String>> getTitle({required String value}) {
    const String prompt = '请使用四到五个字直接返回这句话的简要主题，不要解释、不要标点符号、不要语气助词、不要多余文本。'
        '如果没有主题，请直接返回“随便聊聊”。';
    return _request(messages: [
      Message()
        ..content = value
        ..role = 'user',
      Message()
        ..content = prompt
        ..role = 'user'
    ], model: 'gpt-3.5-turbo-16k');
  }

  Future<String> _getKey() async {
    final bytes = await rootBundle.load('asset/aiproxy.key');
    return utf8.decode(bytes.buffer.asUint8List());
  }

  Future<Stream<String>> _request({
    required List<Message> messages,
    required String model,
  }) async {
    final key = await _getKey();
    final client = http.Client();
    final uri = Uri.parse('https://apivip.aiproxy.io/v1/chat/completions');
    final header = {
      "Content-Type": 'application/json',
      "Authorization": 'Bearer $key'
    };
    if (!model.startsWith('gpt')) {
      model = 'gpt-3.5-turbo-16k';
    }
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
          final delta = data['choices'][0]['delta'];
          controller.add(delta['content'] ?? '');
        }
      }
    }, onDone: () {
      client.close();
      controller.close();
    });
    return controller.stream;
  }
}
