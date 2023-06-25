import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

class OfficialProvider {
  static const String url = 'https://api.openai.com/v1/chat/completions';
  static const double frequencyPenalty = 0;
  static const double temperature = 1;
  String? secretKey;

  Future<Stream<String>> request(
    String messages, {
    String model = 'gpt-3.5-turbo',
  }) async {
    final stream = await _request(messages);
    return stream;
  }

  Future<Stream<String>> generateTitle(String value) async {
    final stream = await _request([
      {'role': 'user', 'content': value},
      {
        'role': 'user',
        'content':
            '请使用四到五个字直接返回这句话的简要主题，不要解释、不要标点符号、不要语气助词、不要多余文本，如果没有主题，请直接返回“闲聊”。',
      },
    ].toString());
    return stream;
  }

  Future<Stream<String>> _request(
    String messages, {
    String model = 'gpt-3.5-turbo',
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $secretKey",
        },
        responseType: ResponseType.stream,
      ),
    );
    var response = await dio.post(url, data: {
      "model": model,
      "messages": messages,
      "stream": true,
    });
    final Stream<List<int>> stream = response.data.stream;
    var controller = StreamController<String>();
    stream.listen((codeUnits) {
      final decodedMessage = utf8.decode(codeUnits);
      final regExp = RegExp(r'"delta":{"content":[\s\S]*?}');
      final matches = regExp.allMatches(decodedMessage);
      if (matches.isNotEmpty) {
        final choices = matches.elementAt(0).group(0);
        final decodedJson = json.decode('{$choices}');
        controller.add(decodedJson['delta']['content']);
      }
    });
    return controller.stream;
  }
}
