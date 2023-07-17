import 'package:isar/isar.dart';

part 'cookie.g.dart';

@collection
@Name('cookies')
class Cookie {
  Id id = Isar.autoIncrement;
  late String cookie;
  @Name('expired_at')
  late int expiredAt;
}
