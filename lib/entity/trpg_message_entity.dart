import 'dart:convert';

class TRPGMessageEntity {
  final int? id;
  final int gameId;
  final String role;
  final String content;
  final List<String> suggestions;
  final DateTime createdAt;

  TRPGMessageEntity({
    this.id,
    required this.gameId,
    required this.role,
    required this.content,
    this.suggestions = const [],
    required this.createdAt,
  });

  factory TRPGMessageEntity.fromJson(Map<String, dynamic> json) {
    List<String> suggestionsList = [];
    if (json['suggestions'] != null) {
      if (json['suggestions'] is String) {
        // 如果是JSON字符串,解析它
        try {
          suggestionsList = List<String>.from(
            jsonDecode(json['suggestions'] as String),
          );
        } catch (e) {
          // 如果解析失败,尝试按逗号分割,并过滤空字符串
          suggestionsList = (json['suggestions'] as String)
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } else if (json['suggestions'] is List) {
        suggestionsList = List<String>.from(json['suggestions']);
      }
    }
    return TRPGMessageEntity(
      id: json['id'] as int?,
      gameId: json['game_id'] as int? ?? 0,
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      suggestions: suggestionsList,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game_id': gameId,
      'role': role,
      'content': content,
      'suggestions': jsonEncode(suggestions),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  TRPGMessageEntity copyWith({
    int? id,
    int? gameId,
    String? role,
    String? content,
    List<String>? suggestions,
    DateTime? createdAt,
  }) {
    return TRPGMessageEntity(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      role: role ?? this.role,
      content: content ?? this.content,
      suggestions: suggestions ?? this.suggestions,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
