import 'package:athena_core/extension/json_map_extension.dart';

/// 快捷入口（Shortcut）：一个独立的一等公民实体，绑定一个 is_preset
/// 的专属 Sentinel，并具备场景级 JSON 输出能力。
///
/// - [name] / [description] / [icon]：卡片展示元数据
/// - [pageTarget]：定制 UI 的目标页标识；null = 默认聊天页
/// - [sentinelId]：绑定的 Sentinel（is_preset），点击后以其身份发起 run
class Shortcut {
  int? id;
  String name;
  String description;
  String icon;
  String? pageTarget;
  int sentinelId;

  Shortcut({
    this.id,
    this.name = '',
    this.description = '',
    this.icon = '',
    this.pageTarget,
    this.sentinelId = 0,
  });

  factory Shortcut.fromJson(Map<String, dynamic> json) {
    return Shortcut(
      id: json.getIntOrNull('id'),
      name: json.getString('name'),
      description: json.getString('description'),
      icon: json.getString('icon'),
      pageTarget: json.getStringOrNull('page_target'),
      sentinelId: json.getInt('sentinel_id'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      if (pageTarget != null) 'page_target': pageTarget,
      'sentinel_id': sentinelId,
    };
  }

  Shortcut copyWith({
    int? id,
    String? name,
    String? description,
    String? icon,
    String? Function()? pageTarget,
    int? sentinelId,
  }) {
    return Shortcut(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      pageTarget: pageTarget != null ? pageTarget() : this.pageTarget,
      sentinelId: sentinelId ?? this.sentinelId,
    );
  }
}
