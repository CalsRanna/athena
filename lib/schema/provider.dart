import 'package:isar/isar.dart';

part 'provider.g.dart';

@collection
@Name('providers')
class Provider {
  Id id = Isar.autoIncrement;
  bool enabled = false;
  String key = '';
  String name = '';
  String url = '';
}
