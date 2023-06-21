import 'dart:io';

import 'package:athena/creator/setting.dart';
import 'package:creator/creator.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

final dioEmitter = Emitter<Dio>(
  (ref, emit) async {
    final setting = await ref.watch(settingEmitter);
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${setting.secretKey}",
        },
        responseType: ResponseType.stream,
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (uri) {
          return 'PROXY ${setting.proxy}';
        };
        return client;
      },
    );
    emit(dio);
  },
  keepAlive: true,
  name: 'dioEmitter',
);
