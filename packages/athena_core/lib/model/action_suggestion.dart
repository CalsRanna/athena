class ActionSuggestion {
  final String emoji;
  final String text;
  final String type; // action/interaction/speech/thinking

  ActionSuggestion({
    required this.emoji,
    required this.text,
    this.type = 'action',
  });

  factory ActionSuggestion.fromJson(Map<String, dynamic> json) {
    return ActionSuggestion(
      emoji: json['emoji'] as String? ?? '',
      text: json['text'] as String? ?? '',
      type: json['type'] as String? ?? 'action',
    );
  }

  Map<String, dynamic> toJson() {
    return {'emoji': emoji, 'text': text, 'type': type};
  }
}
