import 'dart:async';

import 'package:athena_gui/view_model/turn_start_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// 轮次起点缓存的契约。
///
/// 这块逻辑此前长在 ChatViewModel 里，只能靠 `turn_indicator_test` 间接覆盖。
/// 切出来之后这里直接测三件容易写错的事：扫描期间新落库的消息怎么并入、异步扫描
/// 回来时换代次/切走对话怎么处理、删消息按 id 集合怎么裁。
void main() {
  late String? currentChatId;
  late int generation;
  late Completer<List<String>> scan;

  setUp(() {
    currentChatId = 'c1';
    generation = 1;
    scan = Completer<List<String>>();
  });

  TurnStartCache build() => TurnStartCache(
    currentChatId: () => currentChatId,
    currentGeneration: () => generation,
    scan: (_) => scan.future,
  );

  group('缓存与信号', () {
    test('新会话直接记 0 轮，不等扫描', () {
      final subject = build();

      subject.seedEmpty('c1');

      expect(subject.turnStartIds.value, isEmpty);
      // 已建缓存：此后 record 走「已到手就地追加」那条路
      subject.record('c1', 'u1');
      expect(subject.turnStartIds.value, ['u1']);
    });

    test('选会话：有缓存给缓存，没有先空着', () {
      final subject = build();
      subject.seedEmpty('c1');
      subject.record('c1', 'u1');

      subject.selectChat('c1');
      expect(subject.turnStartIds.value, ['u1']);

      currentChatId = 'c2';
      subject.selectChat('c2');
      expect(subject.turnStartIds.value, isEmpty, reason: '没扫过就空着，不给错的数字');
    });
  });

  group('扫描与待并清单', () {
    test('扫描结果与待并清单合并，重复的只留一条', () async {
      final subject = build();
      subject.selectChat('c1');
      subject.record('c1', 'u2'); // 扫描期间新落库

      scan.complete(['u1', 'u2']); // 同一条也被扫到了
      await subject.load('c1', 1);

      expect(subject.turnStartIds.value, ['u1', 'u2']);
    });

    test('待并的那条不在扫描结果里就补在后面', () async {
      final subject = build();
      subject.selectChat('c1');
      subject.record('c1', 'u9');

      scan.complete(['u1', 'u2']);
      await subject.load('c1', 1);

      expect(subject.turnStartIds.value, ['u1', 'u2', 'u9']);
    });

    test('扫描回来时已换代次：只写缓存不动信号', () async {
      final subject = build();
      subject.selectChat('c1');

      final loading = subject.load('c1', 1);
      generation = 2; // 期间又发起了一次加载
      scan.complete(['u1']);
      await loading;

      expect(subject.turnStartIds.value, isEmpty, reason: '过期结果不该上屏');
      subject.selectChat('c1');
      expect(subject.turnStartIds.value, ['u1'], reason: '但缓存仍是写好的');
    });

    test('扫描回来时已切走对话：只写缓存不动信号', () async {
      final subject = build();
      subject.selectChat('c1');

      final loading = subject.load('c1', 1);
      currentChatId = 'c2';
      subject.selectChat('c2');
      scan.complete(['u1']);
      await loading;

      expect(subject.turnStartIds.value, isEmpty, reason: '别把 A 的轮次画到 B 上');

      currentChatId = 'c1';
      subject.selectChat('c1');
      expect(subject.turnStartIds.value, ['u1']);
    });

    test('扫描失败不抛，缓存留空', () async {
      final subject = build();
      subject.selectChat('c1');

      final loading = subject.load('c1', 1);
      scan.completeError(StateError('boom'));
      await loading;

      expect(subject.turnStartIds.value, isEmpty);
    });
  });

  group('就地追加与裁剪', () {
    test('缓存已到手时 record 直接追加，重复的不加', () {
      final subject = build();
      subject.seedEmpty('c1');

      subject.record('c1', 'u1');
      subject.record('c1', 'u1');
      subject.record('c1', null);

      expect(subject.turnStartIds.value, ['u1']);
    });

    test('非当前对话的 record 不写信号', () {
      final subject = build();
      subject.seedEmpty('c1');
      currentChatId = 'c2';

      subject.record('c1', 'u1');

      expect(subject.turnStartIds.value, isEmpty);
    });

    test('prune 按 id 集合裁，当前对话的信号跟着更新', () {
      final subject = build();
      subject.seedEmpty('c1');
      subject.record('c1', 'u1');
      subject.record('c1', 'u2');

      subject.prune('c1', {'u1'});

      expect(subject.turnStartIds.value, ['u2']);
    });

    test('prune 未缓存的对话是 no-op', () {
      final subject = build();

      expect(() => subject.prune('nope', {'u1'}), returnsNormally);
    });
  });

  group('清理', () {
    test('drop 丢掉指定对话；null 是 no-op', () {
      final subject = build();
      subject.seedEmpty('c1');
      subject.record('c1', 'u1');

      expect(() => subject.drop(null), returnsNormally);
      expect(subject.turnStartIds.value, ['u1']);

      subject.drop('c1');
      subject.selectChat('c1');
      expect(subject.turnStartIds.value, isEmpty);
    });

    test('dropMany 与 clear', () {
      final subject = build();
      subject.seedEmpty('c1');
      subject.seedEmpty('c2');
      currentChatId = 'c2';
      subject.record('c2', 'u1');

      subject.dropMany(['c1']);
      subject.selectChat('c2');
      expect(subject.turnStartIds.value, ['u1'], reason: 'c2 没被丢');

      subject.clear();
      expect(subject.turnStartIds.value, isEmpty);
    });
  });
}
