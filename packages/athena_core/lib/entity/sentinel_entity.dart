import 'package:athena_core/extension/json_map_extension.dart';

class SentinelEntity {
  final String? id;
  final String name;
  final String description;
  final String prompt;
  final String tags;
  final bool isPreset;

  const SentinelEntity({
    this.id,
    required this.name,
    this.description = '',
    this.prompt = '',
    this.tags = '',
    this.isPreset = false,
  });

  factory SentinelEntity.fromJson(Map<String, dynamic> json) {
    return SentinelEntity(
      id: json.getStringOrNull('id'),
      name: json.getString('name'),
      description: json.getString('description'),
      prompt: json.getString('prompt'),
      tags: json.getString('tags'),
      isPreset: json.getBool('is_preset'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'prompt': prompt,
      'tags': tags,
      'is_preset': isPreset ? 1 : 0,
    };
  }

  /// 内置角色名。两者都是开箱即用的预设,见 `SentinelSeed.builtins`。
  ///
  /// 这里同时是 `athenaName` 的既有引用点(默认角色回退、directChat 判定),
  /// 新增内置角色时名字要在这里与种子清单同步登记。
  static const athenaName = 'Athena';
  static const daedalusName = 'Daedalus';

  /// 对外展示的内置角色白名单。
  ///
  /// 用白名单而非「预设即隐藏」:预设角色默认不可见,只有明确登记为开箱即用
  /// 的才进选择器。数据仍保留在库中供已存聊天引用解析——所以隐藏一个角色
  /// 不等于删除它。
  static const _listedBuiltins = {athenaName, daedalusName};

  /// 是否在角色列表/选择器中展示。
  ///
  /// 非预设角色全部展示;预设角色仅白名单内的展示。
  bool get isListVisible => !isPreset || _listedBuiltins.contains(name);

  /// 内置角色的名字不可更改。
  ///
  /// 内置角色的身份由名字承载——默认角色回退、直连会话判定、展示白名单都按
  /// 名字匹配,改掉名字会让这些引用同时失准。prompt / description / tags 仍可
  /// 被 `sentinel_evolve` 改进,只是名字要留在原地。
  bool get isNameLocked => isPreset;

  /// 将 tags 字符串转换为列表，用于页面渲染
  List<String> get tagList {
    if (tags.isEmpty) return [];
    return tags.split(',').map((e) => e.trim()).toList();
  }

  SentinelEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? prompt,
    String? tags,
    bool? isPreset,
  }) {
    return SentinelEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      prompt: prompt ?? this.prompt,
      tags: tags ?? this.tags,
      isPreset: isPreset ?? this.isPreset,
    );
  }
}
