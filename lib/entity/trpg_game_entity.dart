class TRPGGameEntity {
  final int? id;
  final String title;
  final String gameStyle;
  final String characterClass;
  final String gameMode;
  final int currentHP;
  final int maxHP;
  final int currentMP;
  final int maxMP;
  final String inventory;
  final String currentQuest;
  final String currentScene;
  final int modelId;
  final DateTime createdAt;
  final DateTime updatedAt;

  TRPGGameEntity({
    this.id,
    required this.title,
    required this.gameStyle,
    required this.characterClass,
    required this.gameMode,
    this.currentHP = 100,
    this.maxHP = 100,
    this.currentMP = 50,
    this.maxMP = 50,
    this.inventory = '',
    this.currentQuest = '',
    this.currentScene = '',
    required this.modelId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TRPGGameEntity.fromJson(Map<String, dynamic> json) {
    return TRPGGameEntity(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      gameStyle: json['game_style'] as String? ?? '',
      characterClass: json['character_class'] as String? ?? '',
      gameMode: json['game_mode'] as String? ?? '',
      currentHP: json['current_hp'] as int? ?? 100,
      maxHP: json['max_hp'] as int? ?? 100,
      currentMP: json['current_mp'] as int? ?? 50,
      maxMP: json['max_mp'] as int? ?? 50,
      inventory: json['inventory'] as String? ?? '',
      currentQuest: json['current_quest'] as String? ?? '',
      currentScene: json['current_scene'] as String? ?? '',
      modelId: json['model_id'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'game_style': gameStyle,
      'character_class': characterClass,
      'game_mode': gameMode,
      'current_hp': currentHP,
      'max_hp': maxHP,
      'current_mp': currentMP,
      'max_mp': maxMP,
      'inventory': inventory,
      'current_quest': currentQuest,
      'current_scene': currentScene,
      'model_id': modelId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  TRPGGameEntity copyWith({
    int? id,
    String? title,
    String? gameStyle,
    String? characterClass,
    String? gameMode,
    int? currentHP,
    int? maxHP,
    int? currentMP,
    int? maxMP,
    String? inventory,
    String? currentQuest,
    String? currentScene,
    int? modelId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TRPGGameEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      gameStyle: gameStyle ?? this.gameStyle,
      characterClass: characterClass ?? this.characterClass,
      gameMode: gameMode ?? this.gameMode,
      currentHP: currentHP ?? this.currentHP,
      maxHP: maxHP ?? this.maxHP,
      currentMP: currentMP ?? this.currentMP,
      maxMP: maxMP ?? this.maxMP,
      inventory: inventory ?? this.inventory,
      currentQuest: currentQuest ?? this.currentQuest,
      currentScene: currentScene ?? this.currentScene,
      modelId: modelId ?? this.modelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
