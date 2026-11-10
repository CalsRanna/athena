import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:test/test.dart';

import '../../support/fake_tool.dart';

void main() {
  late ToolRegistry registry;

  setUp(() {
    registry = ToolRegistry()
      ..register(FakeTool('a'))
      ..register(FakeTool('b'))
      ..register(FakeTool('c'));
  });

  tearDown(() => registry.backgroundTasks.dispose());

  test('null 表示不限制，直接返回原注册表', () {
    expect(identical(registry.filtered(enabled: null), registry), isTrue);
  });

  test('过滤视图保留注册顺序，并共享跨调用资源', () {
    final view = registry.filtered(enabled: {'a', 'c'});

    expect(view.all.map((tool) => tool.name), ['a', 'c']);
    expect(view.definitions.map((d) => d['function']['name']), ['a', 'c']);
    expect(view.get('b'), isNull);
    expect(view.isExcluded('b'), isTrue);
    expect(view.isExcluded('missing'), isFalse, reason: '不存在的工具不是被角色配置禁用');
    expect(identical(view.outputStore, registry.outputStore), isTrue);
    expect(identical(view.backgroundTasks, registry.backgroundTasks), isTrue);
  });
}
