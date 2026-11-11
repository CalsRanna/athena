import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_gui/widget/reasoning_effort.dart';
import 'package:flutter_test/flutter_test.dart';

/// 推理强度的**档位**是引擎的事实（`ChatEntity.reasoningEfforts`），
/// **显示名**是界面文案，两者在这里对接。
///
/// GUI 此前自己抄了一份带显示名的档位表，只靠一句注释断言与 core 同序。
/// core 新增一档时，选择菜单也应列出新档位。
/// 下面两条就是拦这件事的：它们此刻是绿的（两侧同步），价值在于以后漂移时会红。
void main() {
  test('档位清单与 core 同序同长', () {
    expect(
      ReasoningEffort.reasoningEffortOptions
          .map((option) => option.$1)
          .toList(),
      ChatEntity.reasoningEfforts,
      reason: '选择列表按 core 定义的顺序从弱到强排列',
    );
  });

  test('core 的每个档位都有明确的显示名，不是回退成原值', () {
    for (final value in ChatEntity.reasoningEfforts) {
      expect(
        ReasoningEffort.reasoningEffortLabel(value),
        isNot(value),
        reason: '$value 是 core 的档位，但 GUI 没有给它显示名',
      );
    }
  });

  test('未知值回退为原值（存储里可能残留旧档位）', () {
    expect(ReasoningEffort.reasoningEffortLabel('none'), 'none');
  });
}
