import 'dart:async';
import 'dart:convert';

import 'package:athena/model/liaobots_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class LiaobotsProvider {
  final Dio dio = Dio();

  Future<Stream<String>> getTitle({
    required String value,
    required LiaobotsModel model,
  }) {
    const String prompt = '请使用四到五个字直接返回这句话的简要主题，不要解释、不要标点符号、不要语气助词、不要多余文本。'
        '如果没有主题，请直接返回“闲聊”。';
    return _request(messages: [
      {'role': 'user', 'content': value},
      {'role': 'user', 'content': prompt}
    ], model: model);
  }

  Future<Stream<String>> getCompletion({
    required List<Map<String, String?>> messages,
    required LiaobotsModel model,
  }) {
    return _request(messages: messages, model: model);
  }

  Future<List<LiaobotsModel>> getModels() async {
    final key = await _getKey();
    final response = await dio.post(
      'https://liaobots.work/api/models',
      options: Options(headers: {"Cookie": 'gkp2=${key['cookie']}'}),
    );
    final List json = jsonDecode(response.data);
    return json.map((item) => LiaobotsModel.fromJson(item)).toList();
  }

  Future<Map<String, dynamic>> getAccount() async {
    final key = await _getKey();
    final response = await dio.post(
      'https://liaobots.work/api/user',
      data: {"authcode": key['authCode']},
      options: Options(headers: {"Cookie": 'gkp2=${key['cookie']}'}),
    );
    final Map<String, dynamic> account = jsonDecode(response.data);
    return account;
  }

  Future<Map<String, String>> _getKey() async {
    final bytes = await rootBundle.load('asset/liaobots.key');
    final content = utf8.decode(bytes.buffer.asUint8List());
    final patterns = content.split('\n');
    return {
      'authCode': patterns.first.split('=').last,
      'cookie': patterns.last.split('=').last
    };
  }

  Future<Stream<String>> _request({
    required List<Map<String, String?>> messages,
    required LiaobotsModel model,
  }) async {
    final key = await _getKey();
    final response = await dio.post(
      'https://liaobots.work/api/chat',
      data: {"model": model.toJson(), "messages": messages},
      options: Options(
        headers: {
          "x-auth-code": key['authCode'],
          "Cookie": 'gkp2=${key['cookie']}'
        },
        responseType: ResponseType.stream,
      ),
    );
    final Stream<List<int>> stream = response.data.stream;
    final controller = StreamController<String>();
    stream.listen((codeUnits) {
      controller.add(const Utf8Decoder().convert(codeUnits));
    }, onDone: () => controller.close());
    return controller.stream;
  }
}
