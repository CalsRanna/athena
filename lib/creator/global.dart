import 'package:athena/creator/setting.dart';
import 'package:athena/model/chat.dart';
import 'package:athena/model/setting.dart';
import 'package:creator/creator.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:isar/isar.dart';

final isarEmitter = Emitter<Isar>(
  (ref, emit) async {
    final isar = await Isar.open([ChatSchema, SettingSchema]);
    emit(isar);
  },
  keepAlive: true,
  name: 'isarEmitter',
);

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
    dio.httpClientAdapter = IOHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        if (setting.proxyEnabled) {
          client.findProxy = (uri) {
            return 'PROXY ${setting.proxy}';
          };
        }
        return client;
      };
    emit(dio);
  },
  keepAlive: true,
  name: 'dioEmitter',
);
