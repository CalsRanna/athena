import 'package:uuid/uuid.dart';

/// 持久化实体的身份与文件路径、写入顺序解耦；生成 ID 不访问磁盘。
class IdGenerator {
  static const _uuid = Uuid();

  const IdGenerator();

  String next() => _uuid.v7();
}
