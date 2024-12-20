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
    const String prompt = '请用最简短的语言总结出「」中内容的主题。不要解释、不要标点符号、不要语气助词、不要多余文本、长度不得'
        '大于10。只需要告诉我你总结的内容，不需要任何其他文本。并自己判断是否使用英语总结更准确。如果是的话，就使用英语。';
    final List<Message> messages = [
      // Message()
      //   ..content = prompt
      //   ..role = 'system',
      // Claude 系列不支持system，也不支持多个user,所以只能拼接
      Message()
        ..content = '$prompt\n「$value」'
        ..role = 'user',
    ];
    final body = {'model': model, 'messages': messages, 'stream': true};
    return request(body);
  }

  Future<Stream<String>> request(Map<String, dynamic> body) async {
    final uri = Uri.parse('${ProxyConfig.instance.url}/chat/completions');
    final key = ProxyConfig.instance.key;
    final headers = {
      "Content-Type": 'application/json',
      "Authorization": 'Bearer $key'
    };
    final request = Request('post', uri);
    request.headers.addAll(headers);
    request.body = jsonEncode(body);
    final response = await Client().send(request);
    return _decodeStream(response.stream.transform(utf8.decoder));
  }

  Stream<String> _decodeStream(Stream<String> stream) async* {
    final buffer = StringBuffer();
    await for (final chunk in stream) {
      buffer.write(chunk);
      final parts = buffer.toString().split('\n');
      for (int i = 0; i < parts.length - 1; i++) {
        final part = parts[i].replaceAll('data:', '').trim();
        if (part.isEmpty) continue;
        if (part == '[DONE]') return;
        yield* _processPart(part);
      }
      buffer.clear();
      buffer.write(parts.last);
    }
    if (buffer.isNotEmpty) {
      final remaining = buffer.toString().trim();
      if (remaining.isNotEmpty) {
        yield* _processPart(remaining);
      }
    }
  }

  Stream<String> _processPart(String part) async* {
    if (part.trim().isEmpty) return;

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(part);
    } catch (error) {
      yield 'Error processing response: ${error.toString()}';
      return;
    }
    final message = json?['message']?.toString();
    if (message?.isNotEmpty == true) {
      yield message!;
      return;
    }
    final choices = json?['choices'];
    if (choices is! List || choices.isEmpty) return;
    final choice = choices.first;
    if (choice == null || choice['delta'] is! Map) return;
    final content = choice['delta']['content']?.toString() ?? '';
    if (content.isNotEmpty) yield content;
  }
}
