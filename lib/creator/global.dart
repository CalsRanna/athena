import 'package:athena/creator/setting.dart';
import 'package:athena/model/chat.dart';
import 'package:athena/model/setting.dart';
import 'package:creator/creator.dart';
import 'package:dio/dio.dart';
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
    final setting = ref.watch(settingEmitter.asyncData).data;
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${setting?.secretKey}",
        },
        responseType: ResponseType.stream,
      ),
    );
    emit(dio);
  },
  keepAlive: true,
  name: 'dioEmitter',
);
