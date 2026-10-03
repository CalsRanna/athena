import 'package:athena_core/entity/chat_entity.dart';

/// 推理强度的显示名。
///
/// **取值来自 core 的 `ChatEntity.reasoningEfforts`**——档位是引擎的事实，
/// 显示名是界面文案，两件事在这里对接。此前前端自己抄了一份带显示名的档位表，
/// 只靠一句注释断言同序；core 加一档不会有人记得回来改，滑杆就少一个点。
///
/// 之所以逐档写死显示名而不是把值首字母大写：`xhigh` 需要「Extra High」这种
/// 不成规则的写法。core 新增档位而这里没有条目时，[reasoningEffortLabel] 会
/// 回退成原值，`reasoning_effort_test.dart` 会当场报出来。
const _reasoningEffortLabels = <String, String>{
  'low': 'Low',
  'medium': 'Medium',
  'high': 'High',
  'xhigh': 'Extra High',
  'max': 'Max',
};

/// 可选的推理强度档位（从弱到强），顺序即 `ChatEntity.reasoningEfforts`。
///
/// 没有「Default / None / Minimal」：会话上总有一档，新会话默认 high。
/// xhigh / max 只有部分模型支持，选了不支持的档位 API 会 400（与官方一致）。
final List<(String, String)> reasoningEffortOptions = List.unmodifiable([
  for (final value in ChatEntity.reasoningEfforts)
    (value, reasoningEffortLabel(value)),
]);

/// 推理强度的显示名；未知值回退为原值（存储里可能残留已去掉的旧档位）。
String reasoningEffortLabel(String value) =>
    _reasoningEffortLabels[value] ?? value;
