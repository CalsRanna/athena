import 'dart:convert';

import 'package:athena/extension/json_map_extension.dart';

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
    return TRPGMessageEntity(
      id: json.getIntOrNull('id'),
      gameId: json.getInt('game_id'),
      role: json.getString('role', defaultValue: 'user'),
      content: json.getString('content'),
      suggestions: json.getList<String>('suggestions'),
      createdAt: json.getDateTime('created_at'),
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
