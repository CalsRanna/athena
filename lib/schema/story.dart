import 'package:isar/isar.dart';

part 'story.g.dart';

@collection
@Name('stories')
class Story {
  Id id = Isar.autoIncrement;
  String title = '';
  String background = '';
  String style = '';
}
