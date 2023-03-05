import 'package:athena/model/setting.dart';
import 'package:creator/creator.dart';
import 'package:dio/dio.dart';
import 'package:isar/isar.dart';

final isarEmitter = Emitter<Isar>(
  (ref, emit) async {
    final isar = await Isar.open([SettingSchema]);
    emit(isar);
  },
  keepAlive: true,
  name: 'isarEmitter',
);

final secretKeyEmitter = Emitter<String>(
  (ref, emit) async {
    final isar = ref.watch(isarEmitter.asyncData).data;
    final setting = await isar?.settings.where().findFirst();
    final secretKey = setting?.secretKey ?? '';
    emit(secretKey);
  },
  name: 'secretKeyEmitter',
);

final dioEmitter = Emitter<Dio>(
  (ref, emit) async {
    final secretKey = ref.watch(secretKeyEmitter.asyncData).data;
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
    emit(dio);
  },
  keepAlive: true,
  name: 'dioEmitter',
);
