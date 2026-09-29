import 'package:athena_gui/view_model/chat_run_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// 运行态的契约。
///
/// 三条规则原先散在 ViewModel 的约二十处手写，这里直接测它们——尤其是「迟到的收尾
/// 不得抹掉新一轮」：用户发起的 run 以自己的 settled 为准，而在它之后可能已经有新的
/// 一轮登记进来了。
void main() {
  late ChatRunState state;

  setUp(() => state = ChatRunState());

  group('运行指示', () {
    test('重复点亮不会出现两条', () {
      state.beginStreaming('c1');
      state.beginStreaming('c1');

      expect(state.streamingChatIds.value, ['c1']);
      expect(state.isStreaming('c1'), isTrue);
    });

    test('熄灭按 id 过滤，别的对话不受影响', () {
      state.beginStreaming('c1');
      state.beginStreaming('c2');

      state.endStreaming('c1');

      expect(state.streamingChatIds.value, ['c2']);
      expect(state.isStreaming('c1'), isFalse);
    });

    test('熄灭没点亮过的对话是 no-op', () {
      state.beginStreaming('c1');

      expect(() => state.endStreaming('c9'), returnsNormally);
      expect(state.streamingChatIds.value, ['c1']);
    });
  });

  group('实时进度', () {
    test('只清当前显示的对话的进度', () {
      state.noteIteration(3);
      state.noteTool('bash');

      state.clearLiveProgressFor('c1', currentChatId: 'c2');

      expect(state.currentIteration.value, 3, reason: '别的对话的进度不该被这条抹掉');
      expect(state.currentToolName.value, 'bash');
    });

    test('当前对话就是它时清掉', () {
      state.noteIteration(3);
      state.noteTool('bash');

      state.clearLiveProgressFor('c1', currentChatId: 'c1');

      expect(state.currentIteration.value, 0);
      expect(state.currentToolName.value, isNull);
    });
  });

  group('收尾登记', () {
    test('登记后可查、可等', () async {
      final settled = state.registerRun('c1');

      expect(state.hasRun('c1'), isTrue);
      expect(state.settledOf('c1'), isNotNull);
      expect(state.registeredChatIds, ['c1']);

      settled.complete();
      await state.settledOf('c1');
    });

    test('未登记时 settledOf 为 null', () {
      expect(state.settledOf('c1'), isNull);
      expect(state.hasRun('c1'), isFalse);
    });

    test('迟到的收尾抹不掉新一轮的登记', () {
      final first = state.registerRun('c1');
      final second = state.registerRun('c1'); // 新一轮覆盖了登记

      state.unregisterRun('c1', first); // 旧的那次收尾迟到

      expect(state.hasRun('c1'), isTrue, reason: '当前登记的是新一轮');
      expect(state.settledOf('c1'), same(second.future));

      state.unregisterRun('c1', second);
      expect(state.hasRun('c1'), isFalse);
    });
  });

  group('自动汇报记账', () {
    test('点亮与收尾，重复收尾返回 false', () {
      expect(state.isReporting('c1'), isFalse);

      state.markReporting('c1');
      expect(state.isReporting('c1'), isTrue);

      expect(state.takeReportFinished('c1'), isTrue);
      expect(state.isReporting('c1'), isFalse);
      expect(
        state.takeReportFinished('c1'),
        isFalse,
        reason: '重复收尾要能被识别出来，否则会重复熄灭',
      );
    });
  });

  group('还在跑的会话', () {
    test('包含点亮了指示的与登记了收尾的', () {
      state.beginStreaming('c1');
      state.registerRun('c2');

      expect(state.runningChatIds, {'c1', 'c2'});
    });

    test('没有重复项', () {
      state.beginStreaming('c1');
      state.registerRun('c1');

      expect(state.runningChatIds, {'c1'});
    });
  });
}
