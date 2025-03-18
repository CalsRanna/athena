import 'package:isar/isar.dart';

part 'translation.g.dart';

@collection
@Name('translations')
class Translation {
  Id id = Isar.autoIncrement;
  String source = 'Chinese';
  String sourceText = '';
  String target = 'English';
  String targetText = '';

  Translation();

  factory Translation.fromJson(Map<String, dynamic> json) {
    return Translation()
      ..source = json['source']
      ..sourceText = json['source_text']
      ..target = json['target']
      ..targetText = json['target_text'];
  }

  Translation copyWith({
    int? id,
    String? source,
    String? sourceText,
    String? target,
    String? targetText,
  }) {
    return Translation()
      ..id = id ?? this.id
      ..source = source ?? this.source
      ..sourceText = sourceText ?? this.sourceText
      ..target = target ?? this.target
      ..targetText = targetText ?? this.targetText;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'source_text': sourceText,
      'target': target,
      'target_text': targetText,
    };
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
