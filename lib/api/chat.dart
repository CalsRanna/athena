import 'dart:async';

import 'package:athena/api/api.dart';
import 'package:athena/schema/chat.dart';

class ChatApi with Api {
  Future<Stream<String>> getCompletion({required List<Message> messages}) {
    final body = {
      'model': model,
      'messages': messages,
      'stream': true,
    };
    return request(body: body, method: 'post', url: '/chat/completions');
  }

  Future<Stream<String>> getTitle({required String value}) {
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
    final body = {
      'model': model,
      'messages': messages,
      'stream': true,
    };
    return request(body: body, method: 'post', url: '/chat/completions');
  }
}
