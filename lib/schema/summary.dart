import 'package:isar/isar.dart';

part 'summary.g.dart';

@Collection(accessor: 'summaries')
@Name('summaries')
class Summary {
  Id id = Isar.autoIncrement;
  String content = '';
  String html = '';
  String icon = '';
  String link = '';
  String title = '';

  Summary copyWith({
    int? id,
    String? content,
    String? html,
    String? icon,
    String? link,
    String? title,
  }) {
    return Summary()
      ..id = id ?? this.id
      ..content = content ?? this.content
      ..html = html ?? this.html
      ..icon = icon ?? this.icon
      ..link = link ?? this.link
      ..title = title ?? this.title;
  }
}
