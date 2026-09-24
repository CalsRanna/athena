import 'package:athena_core/agent/elicit/elicit_prompt.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';

/// 向用户提结构化问题（「你要哪个」），与审批弹窗（「要不要做」）分开。
///
/// 形状与用法对齐 Claude Code 的 AskUserQuestion：每次 1-4 问、每问 2-4 选项、
/// header ≤12 字符、用户永远可以自填、推荐项放首位并标 `(Recommended)`。
/// 使用条件是**判据式**而非计数式：只在卡住一个真正属于用户的决定、
/// 且从请求/代码/合理默认都推不出来时才问——这条判据写在工具描述里，
/// 随工具一起下发给模型，不依赖某个角色的提示词。
class AskUserQuestionTool implements Tool, ElicitChannelAware {
  /// 硬约束：与 Claude Code 一致（每次调用 1-4 问、每问 2-4 选项）。
  static const int maxQuestions = 4;
  static const int minOptionsPerQuestion = 2;
  static const int maxOptionsPerQuestion = 4;
  static const int maxHeaderLength = 12;

  /// 没有提问 UI 时的降级提示。
  ///
  /// 这里刻意**不用** "Error:" 开头：报错会记入 toolFailures 并可能触发
  /// Reflection 重试，而"环境里没有人可问"重试多少次都一样。
  static const String noChannelMessage =
      'No interactive user input is available in this session. '
      'Do not call ask_user_question again: proceed with a sensible default '
      'and state the assumption you made explicitly in your reply.';

  static const String noAnswerMessage =
      'The user did not answer. Do not call ask_user_question again for the '
      'same decision: proceed with a sensible default and state the '
      'assumption you made explicitly in your reply.';

  @override
  String get name => 'ask_user_question';

  /// 串行：执行期间等待用户作答，不能与其他调用并发。
  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;

  @override
  bool canExecuteParallel(Map<String, dynamic> args) => false;

  @override
  String get description =>
      'Ask the user a multiple-choice question when you are blocked on a '
      'decision that is genuinely theirs to make — one you cannot resolve '
      'from the request, the code, or a sensible default.\n'
      'Never use it to ask what to do next, to check whether your plan or '
      'your previous message is acceptable, or for anything you could find '
      'out yourself by reading files, running commands, or searching the '
      'web: research first, then ask only if a real fork remains.\n'
      'Usage: 1-4 questions per call, 2-4 options each, header at most 12 '
      'characters. The user can always type a free-form answer instead of '
      'picking an option. If you recommend one option, put it first and '
      'append " (Recommended)" to its label. Set multiSelect: true when '
      'several options can be chosen together. Ask everything you need in '
      'one call rather than several rounds.';

  @override
  Map<String, dynamic> get parameters => <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'questions': <String, dynamic>{
        'type': 'array',
        'minItems': 1,
        'maxItems': maxQuestions,
        'description': 'Questions to ask the user (1-4).',
        'items': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'question': <String, dynamic>{
              'type': 'string',
              'description': 'The full question text to display.',
            },
            'header': <String, dynamic>{
              'type': 'string',
              'maxLength': maxHeaderLength,
              'description':
                  'Short label for the question (max 12 characters).',
            },
            'multiSelect': <String, dynamic>{
              'type': 'boolean',
              'description': 'True when several options can be selected.',
            },
            'options': <String, dynamic>{
              'type': 'array',
              'minItems': minOptionsPerQuestion,
              'maxItems': maxOptionsPerQuestion,
              'description':
                  'Choices (2-4). Put your recommended option first and '
                  'append " (Recommended)" to its label.',
              'items': <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{
                  'label': <String, dynamic>{
                    'type': 'string',
                    'description': 'Short option label.',
                  },
                  'description': <String, dynamic>{
                    'type': 'string',
                    'description': 'What choosing this option means.',
                  },
                },
                'required': <String>['label', 'description'],
              },
            },
          },
          'required': <String>['question', 'header', 'options'],
        },
      },
    },
    'required': <String>['questions'],
  };

  /// 没有注入提问通道时的兜底（移动端 / 未配置 onElicit / 子代理）。
  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async => noChannelMessage;

  @override
  Future<String> executeWithElicit(
    Map<String, dynamic> args, {
    required ElicitChannel channel,
    void Function(String)? onUpdate,
  }) async {
    final parsed = _parseQuestions(args);
    if (parsed.error != null) return parsed.error!;

    final questions = parsed.questions!;
    if (!channel.available) return noChannelMessage;

    final answers = await channel.ask(questions);
    if (answers == null || answers.isEmpty) return noAnswerMessage;
    return _formatAnswers(questions, answers);
  }

  /// 本地校验嵌套形状。
  ///
  /// 引擎的 `SchemaValidator` 只看顶层必填与类型（不递归 items、也不认
  /// minItems/maxItems），所以「1-4 问、每问 2-4 选、header ≤12」由这里兜住；
  /// schema 里的同类关键字只用于提示模型，不构成保证。
  ({List<ElicitQuestion>? questions, String? error}) _parseQuestions(
    Map<String, dynamic> args,
  ) {
    final raw = args['questions'];
    if (raw is! List || raw.isEmpty) {
      return (
        questions: null,
        error: _invalid('"questions" must be a non-empty array.'),
      );
    }
    if (raw.length > maxQuestions) {
      return (
        questions: null,
        error: _invalid(
          'at most $maxQuestions questions per call, got ${raw.length}.',
        ),
      );
    }

    final questions = <ElicitQuestion>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) {
        return (
          questions: null,
          error: _invalid('questions[$i] must be an object.'),
        );
      }
      final map = item.cast<String, dynamic>();
      final question = map['question'];
      final header = map['header'];
      if (question is! String || question.trim().isEmpty) {
        return (
          questions: null,
          error: _invalid('questions[$i].question must be a non-empty string.'),
        );
      }
      if (header is! String || header.trim().isEmpty) {
        return (
          questions: null,
          error: _invalid('questions[$i].header must be a non-empty string.'),
        );
      }
      if (header.runes.length > maxHeaderLength) {
        return (
          questions: null,
          error: _invalid(
            'questions[$i].header has ${header.runes.length} characters, '
            'max is $maxHeaderLength.',
          ),
        );
      }

      final rawOptions = map['options'];
      if (rawOptions is! List ||
          rawOptions.length < minOptionsPerQuestion ||
          rawOptions.length > maxOptionsPerQuestion) {
        return (
          questions: null,
          error: _invalid(
            'questions[$i].options must contain '
            '$minOptionsPerQuestion-$maxOptionsPerQuestion entries.',
          ),
        );
      }

      final options = <ElicitOption>[];
      for (var j = 0; j < rawOptions.length; j++) {
        final rawOption = rawOptions[j];
        if (rawOption is! Map) {
          return (
            questions: null,
            error: _invalid('questions[$i].options[$j] must be an object.'),
          );
        }
        final option = rawOption.cast<String, dynamic>();
        final label = option['label'];
        final description = option['description'];
        if (label is! String ||
            label.trim().isEmpty ||
            description is! String ||
            description.trim().isEmpty) {
          return (
            questions: null,
            error: _invalid(
              'questions[$i].options[$j] needs non-empty "label" and "description".',
            ),
          );
        }
        options.add(ElicitOption(label: label, description: description));
      }

      final multiSelect = map['multiSelect'];
      if (multiSelect != null && multiSelect is! bool) {
        return (
          questions: null,
          error: _invalid('questions[$i].multiSelect must be a boolean.'),
        );
      }

      questions.add(
        ElicitQuestion(
          question: question,
          header: header,
          options: options,
          multiSelect: multiSelect == true,
        ),
      );
    }

    return (questions: questions, error: null);
  }

  String _invalid(String detail) =>
      'Error: Invalid arguments for tool "$name": $detail';

  /// 把答案交回模型：按提问顺序逐行，未作答的问题显式标出。
  String _formatAnswers(
    List<ElicitQuestion> questions,
    Map<String, String> answers,
  ) {
    final buffer = StringBuffer('User answers:');
    for (final question in questions) {
      final answer = answers[question.question];
      buffer.write('\n- ${question.header}: ${question.question} -> ');
      buffer.write(
        answer == null || answer.trim().isEmpty ? '(no answer)' : answer,
      );
    }
    return buffer.toString();
  }
}
