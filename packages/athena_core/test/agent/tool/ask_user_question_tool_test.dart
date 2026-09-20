import 'dart:async';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/elicit/elicit_prompt.dart';
import 'package:athena_core/agent/tool/ask_user_question_tool.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:test/test.dart';

const String _header = '格式';

Map<String, dynamic> option(String label) => <String, dynamic>{
  'label': label,
  'description': '选择 $label 的含义',
};

Map<String, dynamic> questionJson({
  String question = '输出用哪种格式？',
  String header = _header,
  List<Map<String, dynamic>>? options,
  Object? multiSelect,
}) => <String, dynamic>{
  'question': question,
  'header': header,
  'options': options ?? [option('摘要'), option('详细')],
  if (multiSelect != null) 'multiSelect': multiSelect,
};

void main() {
  final tool = AskUserQuestionTool();

  ElicitChannel channel(ElicitPrompt? prompt, {CancelToken? cancelToken}) =>
      ElicitChannel(
        chatId: 7,
        prompt: prompt,
        cancelToken: cancelToken ?? CancelToken(),
      );

  group('元数据与描述', () {
    test('只读 + 串行：交互由宿主卡片承载，不进审批弹窗', () {
      expect(tool.name, 'ask_user_question');
      expect(tool.risk, ToolRisk.readOnly);
      expect(tool.executionMode, ExecutionMode.sequential);
      expect(tool.canExecuteParallel(<String, dynamic>{}), isFalse);
      expect(tool.parameters['required'], contains('questions'));
    });

    test('使用判据随工具描述下发，不依赖某个角色的提示词', () {
      // 判据式（而非计数式）：只在真正属于用户的决定上问
      expect(tool.description, contains('genuinely theirs to make'));
      expect(tool.description, contains('cannot resolve'));
      // 用法约定
      expect(tool.description, contains('(Recommended)'));
      expect(tool.description, contains('free-form'));
      expect(tool.description, contains('multiSelect'));
    });

    test('模型看到的定义里带嵌套形状约束，且保留引擎注入的调用元数据', () {
      final definition = ToolRegistry.parametersFor(tool);
      final properties = definition['properties'] as Map<String, dynamic>;

      final questions = properties['questions'] as Map<String, dynamic>;
      expect(questions['type'], 'array');
      expect(questions['minItems'], 1);
      expect(questions['maxItems'], AskUserQuestionTool.maxQuestions);

      final item = questions['items'] as Map<String, dynamic>;
      expect(
        item['required'],
        containsAll(<String>['question', 'header', 'options']),
      );
      final itemProperties = item['properties'] as Map<String, dynamic>;
      expect(
        (itemProperties['header'] as Map<String, dynamic>)['maxLength'],
        AskUserQuestionTool.maxHeaderLength,
      );

      final options = itemProperties['options'] as Map<String, dynamic>;
      expect(options['minItems'], AskUserQuestionTool.minOptionsPerQuestion);
      expect(options['maxItems'], AskUserQuestionTool.maxOptionsPerQuestion);

      // call_description / approval_recommendation / approval_reason
      // 由注册表统一注入，工具自身不重复声明
      expect(properties, contains('call_description'));
      expect(properties, contains('approval_recommendation'));
      // call_description 由注册表加入 required，其余业务必填字段保持原样
      expect(definition['required'], <String>['questions', 'call_description']);
    });
  });

  group('通道缺失时降级而非报错', () {
    test('未注入 onElicit：返回降级提示且不以 Error 开头', () async {
      final result = await tool.execute(<String, dynamic>{
        'questions': [questionJson()],
      });
      expect(result, AskUserQuestionTool.noChannelMessage);
      expect(result.startsWith('Error'), isFalse);
    });

    test('通道存在但没有回调：同样降级', () async {
      final result = await tool.executeWithElicit(<String, dynamic>{
        'questions': [questionJson()],
      }, channel: channel(null));
      expect(result, AskUserQuestionTool.noChannelMessage);
    });
  });

  group('作答回传', () {
    test('单选：问题与答案按提问顺序交回，并带上 chatId', () async {
      late List<ElicitQuestion> asked;
      var seenChatId = -1;
      final result = await tool.executeWithElicit(
        <String, dynamic>{
          'questions': [questionJson()],
        },
        channel: channel((chatId, questions, _) async {
          seenChatId = chatId;
          asked = questions;
          return <String, String>{'输出用哪种格式？': '摘要'};
        }),
      );

      expect(seenChatId, 7);
      expect(asked, hasLength(1));
      expect(asked.single.header, _header);
      expect(asked.single.multiSelect, isFalse);
      expect(asked.single.options.map((o) => o.label), ['摘要', '详细']);
      expect(result, contains('User answers:'));
      expect(result, contains('$_header: 输出用哪种格式？ -> 摘要'));
    });

    test('多选：多个 label 原样回传；用户自填文本也原样回传', () async {
      final result = await tool.executeWithElicit(
        <String, dynamic>{
          'questions': [
            questionJson(question: '包含哪些部分？', multiSelect: true),
            questionJson(question: '还要注意什么？'),
          ],
        },
        channel: channel(
          (_, _, _) async => <String, String>{
            '包含哪些部分？': '摘要, 详细',
            '还要注意什么？': '别用 emoji',
          },
        ),
      );

      expect(result, contains('包含哪些部分？ -> 摘要, 详细'));
      expect(result, contains('还要注意什么？ -> 别用 emoji'));
    });

    test('某题未作答：显式标出，不猜测', () async {
      final result = await tool.executeWithElicit(<String, dynamic>{
        'questions': [questionJson()],
      }, channel: channel((_, _, _) async => <String, String>{}));

      // 空答案整体视为未作答
      expect(result, AskUserQuestionTool.noAnswerMessage);
    });

    test('等待期间 run 被取消：立即返回未作答，不挂死', () async {
      final token = CancelToken();
      final pending = Completer<Map<String, String>?>();
      final future = tool.executeWithElicit(<String, dynamic>{
        'questions': [questionJson()],
      }, channel: channel((_, _, _) => pending.future, cancelToken: token));

      await Future<void>.delayed(Duration.zero);
      token.cancel();

      expect(await future, AskUserQuestionTool.noAnswerMessage);
      pending.complete(null);
    });
  });

  group('形状校验：在本地兜住引擎校验器不递归的缺口', () {
    final invalid = <String, Map<String, dynamic>>{
      'problems 非数组': <String, dynamic>{'questions': '用哪种格式？'},
      '问题为空数组': <String, dynamic>{'questions': <Object>[]},
      '问题数超过 4': <String, dynamic>{
        'questions': [for (var i = 0; i < 5; i++) questionJson()],
      },
      '选项少于 2': <String, dynamic>{
        'questions': [
          questionJson(options: [option('只有一个')]),
        ],
      },
      '选项多于 4': <String, dynamic>{
        'questions': [
          questionJson(options: [for (var i = 0; i < 5; i++) option('选项$i')]),
        ],
      },
      'header 超过 12 字符': <String, dynamic>{
        'questions': [questionJson(header: '一二三四五六七八九十十一十二十三')],
      },
      '问题文本为空': <String, dynamic>{
        'questions': [questionJson(question: '   ')],
      },
      '选项缺 description': <String, dynamic>{
        'questions': [
          questionJson(
            options: [
              <String, dynamic>{'label': '只有标签'},
              option('详细'),
            ],
          ),
        ],
      },
      'multiSelect 非布尔': <String, dynamic>{
        'questions': [questionJson(multiSelect: 'yes')],
      },
    };

    for (final entry in invalid.entries) {
      test('${entry.key} → 报可纠正的错误，且不惊动用户', () async {
        var asked = false;
        final result = await tool.executeWithElicit(
          entry.value,
          channel: channel((_, _, _) async {
            asked = true;
            return <String, String>{};
          }),
        );

        expect(
          result,
          startsWith('Error: Invalid arguments for tool "ask_user_question": '),
        );
        expect(asked, isFalse);
      });
    }
  });
}
