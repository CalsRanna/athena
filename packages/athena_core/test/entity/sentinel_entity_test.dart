import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:test/test.dart';

void main() {
  SentinelEntity sentinel({
    String name = 'X',
    bool isPreset = false,
  }) => SentinelEntity(name: name, isPreset: isPreset);

  group('isListVisible', () {
    test('非预设角色全部展示', () {
      expect(sentinel(name: '自定义角色').isListVisible, isTrue);
      expect(sentinel(name: 'Athena').isListVisible, isTrue);
    });

    test('预设角色仅 Athena 展示', () {
      expect(sentinel(name: 'Athena', isPreset: true).isListVisible, isTrue);
      expect(sentinel(name: '其他内置', isPreset: true).isListVisible, isFalse);
    });
  });
}
