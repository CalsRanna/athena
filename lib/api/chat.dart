import 'dart:async';
import 'dart:convert';

import 'package:athena/schema/chat.dart';
import 'package:athena/util/proxy.dart';
import 'package:http/http.dart';

class ChatApi {
  Future<Stream<String>> getCompletion(
    List<Map<String, String>> messages, {
    required String model,
  }) {
    final body = {'model': model, 'messages': messages, 'stream': true};
    return request(body);
  }

  Future<Stream<String>> getTitle(String value, {required String model}) {
    const String prompt = '请使用四到五个字描述上面这句话的简要主题，而不是回答这句话提及到的问题。'
        '不要解释、不要标点符号、不要语气助词、不要多余文本。'
        '如果没有主题，请直接返回“闲聊”。';
    final List<Message> messages = [
      Message()
        ..content = value
        ..role = 'user',
      Message()
        ..content = prompt
        ..role = 'user',
    ];
    final body = {'model': model, 'messages': messages, 'stream': true};
    return request(body);
  }

  Future<Stream<String>> request(Map<String, dynamic> body) async {
    final uri = Uri.parse('${ProxyConfig.instance.url}/chat/completions');
    final key = ProxyConfig.instance.key;
    final header = {
      "Content-Type": 'application/json',
      "Authorization": 'Bearer $key'
    };
    final request = Request('post', uri);
    request.headers.addAll(header);
    request.body = jsonEncode(body);
    final response = await Client().send(request);
    final controller = StreamController<String>();
    response.stream.transform(utf8.decoder).listen((chunk) {
      chunk = chunk.replaceAll('data:', '').trim();
      // chunk may contains multiple messages, string buffer would be better
      final parts = chunk.split('\n');
      for (final part in parts) {
        if (part.isEmpty) continue;
        if (part.trim() == '[DONE]') return;
        print('[chunk]$part');
        try {
          final json = jsonDecode(part);
          if (json['choices'] == null) throw Exception(part);
          final content = json['choices'][0]['delta']['content'] ?? '';
          controller.add(content);
        } catch (error) {
          print('[error]$error');
          controller.add('[🐛]');
        }
      }
    }, onDone: () {
      controller.close();
    });
    return controller.stream;
  }
}
