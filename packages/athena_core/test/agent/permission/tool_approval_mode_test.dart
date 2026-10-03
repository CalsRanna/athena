import 'dart:convert';

import 'package:athena_core/agent/agent_event.dart';
import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/elicit/elicit_prompt.dart';
import 'package:athena_core/agent/permission/ai_permission_reviewer.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/bash_shell_tool.dart';
import 'package:athena_core/agent/tool/ask_user_question_tool.dart';
import 'package:athena_core/agent/tool/file_read_tool.dart';
import 'package:athena_core/agent/tool/file_write_tool.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

void main() {
  late _ToolCompletionService completion;
  late ToolRegistry registry;
  late PermissionStore store;
  late List<String> prompts;
  late List<String?> reviewReasons;
  late _StubFileReadTool fileRead;

  setUp(() {
    completion = _ToolCompletionService();
    fileRead = _StubFileReadTool();
    registry = ToolRegistry()
      ..register(_StubBashTool())
      ..register(fileRead)
      ..register(_StubFileWriteTool())
      ..register(AskUserQuestionTool());
    store = PermissionStore();
    prompts = [];
    reviewReasons = [];
  });

  tearDown(() => registry.backgroundTasks.dispose());

  Future<AgentToolResultEvent> run(
    ApprovalMode mode, {
    bool approved = false,
    bool withPermissionService = true,
    bool withApprovalCallback = true,
    ElicitPrompt? onElicit,
    void Function()? duringApproval,
  }) async {
    final now = DateTime(2026, 9, 24);
    final service = AgentService(
      chatService: completion,
      toolRegistry: registry,
    );
    final events = await service
        .run(
          runId: 1,
          chat: ChatEntity(
            id: '1',
            title: 'test',
            modelId: '1',
            sentinelId: ChatEntity.noSentinelId,
            createdAt: now,
            updatedAt: now,
          ),
          provider: ProviderEntity(
            name: 'test',
            baseUrl: 'https://example.invalid',
            apiKey: 'test',
            createdAt: now,
          ),
          model: ModelEntity(
            name: 'test',
            modelId: 'test',
            providerId: '1',
            createdAt: now,
            updatedAt: now,
          ),
          baseMessages: [ChatMessage.user('查看仓库状态')],
          hasSentinelPrompt: false,
          permissionService: withPermissionService
              ? PermissionService(store: store)
              : null,
          permissionReviewContext: mode == ApprovalMode.aiReview
              ? PermissionReviewContext.fromMessages([
                  MessageEntity(chatId: '1', role: 'user', content: '查看仓库状态'),
                ])
              : null,
          bypassPermissions: mode == ApprovalMode.bypass,
          onPermission: withApprovalCallback
              ? (_, arguments, {reviewReason}) async {
                  duringApproval?.call();
                  prompts.add(arguments);
                  reviewReasons.add(reviewReason);
                  return approved;
                }
              : null,
          onElicit: onElicit,
        )
        .toList();
    final results = events.whereType<AgentToolResultEvent>().toList();
    expect(
      results,
      hasLength(
        completion.callCount * (completion.nextToolName == null ? 1 : 2),
      ),
    );
    return results.last;
  }

  test('手动模式下 git status 必须由用户批准', () async {
    final result = await run(ApprovalMode.manual);
    expect(result.status, ToolResultStatus.blocked);
    expect(prompts, hasLength(1));
    expect(jsonDecode(prompts.single)['command'], 'git status');
    expect(completion.reviews, isEmpty);
  });

  test('手动模式批准后执行 shell', () async {
    final result = await run(ApprovalMode.manual, approved: true);
    expect(result.status, ToolResultStatus.success);
    expect(result.result, 'shell executed');
    expect(prompts, hasLength(1));
  });

  test('AI 模式下 git status 经过独立审核后执行', () async {
    final result = await run(ApprovalMode.aiReview);
    expect(result.status, ToolResultStatus.success);
    expect(result.result, 'shell executed');
    expect(result.approvalReview?['decision'], 'allow');
    expect(completion.reviews, hasLength(1));
    expect(completion.reviews.single, contains('git status'));
    expect(prompts, isEmpty);
  });

  test('AI 无法确认时转人工,拒绝后不执行', () async {
    completion.reviewDecision = 'ask';
    final result = await run(ApprovalMode.aiReview);
    expect(result.status, ToolResultStatus.blocked);
    expect(result.approvalReview?['decision'], 'ask');
    expect(prompts, hasLength(1));
  });

  test('所有权限模式直接执行,不请求 AI 或人工审核', () async {
    final result = await run(ApprovalMode.bypass);
    expect(result.status, ToolResultStatus.success);
    expect(result.result, 'shell executed');
    expect(completion.reviews, isEmpty);
    expect(prompts, isEmpty);
  });

  for (final mode in ApprovalMode.values) {
    test('${mode.key} 模式统一处理文件读取', () async {
      completion.toolName = 'file_read';
      completion.arguments = {'path': '/workspace/notes.txt'};
      final result = await run(mode);
      if (mode == ApprovalMode.manual) {
        expect(result.status, ToolResultStatus.blocked);
        expect(fileRead.executions, 0);
        expect(prompts, hasLength(1));
        expect(completion.reviews, isEmpty);
      } else {
        expect(result.status, ToolResultStatus.success);
        expect(result.result, 'file content');
        expect(fileRead.executions, 1);
        expect(prompts, isEmpty);
        expect(
          completion.reviews,
          hasLength(mode == ApprovalMode.aiReview ? 1 : 0),
        );
      }
    });

    test('${mode.key} 模式仍执行完整命令的 deny 规则', () async {
      store.rules.add(
        const PermissionRule(
          tool: 'bash',
          kind: RuleKind.exact,
          pattern: 'git status',
        ),
      );
      final result = await run(mode, approved: true);
      expect(result.status, ToolResultStatus.blocked);
      expect(result.result, contains('denied by a permission rule'));
      expect(completion.reviews, isEmpty);
      expect(prompts, isEmpty);
    });
  }

  test('所有权限模式保留文件读取的并行能力', () async {
    completion.toolName = 'file_read';
    completion.callCount = 2;
    completion.arguments = {
      'path': '/workspace/notes.txt',
      'approval_recommendation': 'ask',
    };
    await run(ApprovalMode.bypass);
    expect(fileRead.maxConcurrent, 2);
    expect(fileRead.executions, 2);
    expect(prompts, isEmpty);
  });

  test('需要人工批准的文件读取保持串行', () async {
    completion.toolName = 'file_read';
    completion.callCount = 2;
    completion.arguments = {'path': '/workspace/notes.txt'};
    await run(ApprovalMode.manual, approved: true);
    expect(fileRead.maxConcurrent, 1);
    expect(prompts, hasLength(2));
  });

  test('所有权限模式的并行调用也不能越过 deny', () async {
    completion.toolName = 'file_read';
    completion.callCount = 2;
    completion.arguments = {'path': '/workspace/notes.txt'};
    store.rules.add(
      const PermissionRule(
        tool: 'file_read',
        kind: RuleKind.path,
        pattern: '/workspace',
      ),
    );
    final result = await run(ApprovalMode.bypass);
    expect(result.status, ToolResultStatus.blocked);
    expect(fileRead.executions, 0);
    expect(prompts, isEmpty);
  });

  test('提问工具直接进入提问通道,不叠加 AI 或人工审批', () async {
    completion.toolName = 'ask_user_question';
    completion.arguments = {
      'approval_recommendation': 'ask',
      'questions': [
        {
          'question': '选哪个？',
          'header': '选择',
          'options': [
            {'label': 'A', 'description': '方案 A'},
            {'label': 'B', 'description': '方案 B'},
          ],
        },
      ],
    };
    var questionsShown = 0;
    final result = await run(
      ApprovalMode.aiReview,
      onElicit: (_, questions, _) async {
        questionsShown++;
        return {questions.single.question: 'A'};
      },
    );
    expect(result.status, ToolResultStatus.success);
    expect(result.result, contains('A'));
    expect(questionsShown, 1);
    expect(prompts, isEmpty);
    expect(completion.reviews, isEmpty);
  });

  test('AI 审核期间新增的 deny 优先于模型批准', () async {
    completion.duringReview = () => store.rules.add(
      const PermissionRule(
        tool: 'bash',
        kind: RuleKind.exact,
        pattern: 'git status',
      ),
    );
    final result = await run(ApprovalMode.aiReview);
    expect(result.status, ToolResultStatus.blocked);
    expect(result.result, contains('denied by a permission rule'));
    expect(prompts, isEmpty);
  });

  test('人工等待期间新增的 deny 优先于当次批准', () async {
    final result = await run(
      ApprovalMode.manual,
      approved: true,
      duringApproval: () => store.rules.add(
        const PermissionRule(
          tool: 'bash',
          kind: RuleKind.exact,
          pattern: 'git status',
        ),
      ),
    );
    expect(result.status, ToolResultStatus.blocked);
    expect(prompts, hasLength(1));
  });

  for (final response in ['not JSON', '{"decision":"invalid","reason":"x"}']) {
    test('AI 返回无效响应时转人工并携带回退原因：$response', () async {
      completion.reviewResponse = response;
      final result = await run(ApprovalMode.aiReview, approved: true);
      expect(result.status, ToolResultStatus.success);
      expect(result.approvalReview?['source'], 'fallback');
      expect(prompts, hasLength(1));
      expect(reviewReasons.single, isNotEmpty);
    });
  }

  test('工具 schema 不再让主 Agent 建议审批，保留调用说明', () {
    for (final tool in registry.all) {
      final properties = ToolRegistry.parametersFor(tool)['properties'] as Map;
      expect(properties, isNot(contains('approval_recommendation')));
      expect(properties, isNot(contains('approval_reason')));
      expect(properties, contains('call_description'));
    }
  });

  test('AI 模式每次审核文件写入，旧 ask 元数据不会强制人工审批', () async {
    completion.toolName = 'file_write';
    completion.callCount = 2;
    completion.arguments = {
      'path': '/workspace/example.dart',
      'content': 'code',
      'approval_recommendation': 'ask',
      'approval_reason': 'legacy suggestion',
    };
    final result = await run(ApprovalMode.aiReview);
    expect(result.status, ToolResultStatus.success);
    expect(completion.reviews, hasLength(2));
    expect(prompts, isEmpty);
  });

  test('Manual 相同写入也逐次问用户，不复用批准', () async {
    completion.toolName = 'file_write';
    completion.callCount = 2;
    completion.arguments = {
      'path': '/workspace/example.dart',
      'content': 'code',
    };
    await run(ApprovalMode.manual, approved: true);
    expect(prompts, hasLength(2));
    expect(reviewReasons, everyElement(isNull));
    expect(completion.reviews, isEmpty);
  });

  test('AI 转人工时传递原因，单次人工批准不会跳过后续 AI 审核', () async {
    completion.reviewDecision = 'ask';
    completion.callCount = 2;
    await run(ApprovalMode.aiReview, approved: true);
    expect(completion.reviews, hasLength(2));
    expect(prompts, hasLength(2));
    expect(reviewReasons, everyElement('测试审批结果'));
  });

  test('用户拒绝后的相同调用不重试、不再发起 AI 或人工审批', () async {
    completion.reviewDecision = 'ask';
    completion.callCount = 2;
    final result = await run(ApprovalMode.aiReview);
    expect(result.status, ToolResultStatus.blocked);
    expect(completion.reviews, hasLength(1));
    expect(prompts, hasLength(1));
  });

  test('提问卡实际回答通过宿主进入同轮后续审核，不信任工具结果授权', () async {
    completion.toolName = 'ask_user_question';
    completion.arguments = {
      'questions': [
        {
          'question': '输出使用哪个格式？',
          'header': '格式',
          'options': [
            {'label': 'JSON', 'description': '结构化数据'},
            {'label': 'TXT', 'description': '纯文本'},
          ],
        },
      ],
    };
    completion.nextToolName = 'file_write';
    completion.nextArguments = {
      'path': '/workspace/output.json',
      'content': '{}',
    };
    final result = await run(
      ApprovalMode.aiReview,
      onElicit: (_, questions, _) async => {questions.single.question: 'JSON'},
    );
    expect(result.status, ToolResultStatus.success);
    expect(completion.reviews, hasLength(1));
    expect(completion.reviews.single, contains('user_answers'));
    expect(completion.reviews.single, contains('输出使用哪个格式？'));
    expect(completion.reviews.single, contains('JSON'));
    expect(prompts, isEmpty);
  });

  test('缺少权限服务与审批回调时文件读取也被拒绝', () async {
    completion.toolName = 'file_read';
    completion.arguments = {'path': '/workspace/notes.txt'};
    final result = await run(
      ApprovalMode.bypass,
      withPermissionService: false,
      withApprovalCallback: false,
    );
    expect(result.status, ToolResultStatus.blocked);
    expect(result.result, contains('no permission service'));
    expect(fileRead.executions, 0);
  });
}

/// 复用真实 shell 的权限与并行配置,执行替身避免启动本机进程。
class _StubBashTool extends BashShellTool {
  @override
  Future<ToolExecutionResult> executeCancellable(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    required Future<void> cancelSignal,
  }) async => const ToolExecutionResult.success('shell executed');
}

class _StubFileReadTool extends FileReadTool {
  @override
  Future<ToolExecutionResult> executeCancellable(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    required Future<void> cancelSignal,
  }) => executeResult(args, onUpdate: onUpdate);

  int executions = 0;
  int _active = 0;
  int maxConcurrent = 0;

  @override
  Future<ToolExecutionResult> executeResult(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    executions++;
    _active++;
    if (_active > maxConcurrent) maxConcurrent = _active;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _active--;
    return const ToolExecutionResult.success('file content');
  }
}

class _StubFileWriteTool extends FileWriteTool {
  @override
  Future<ToolExecutionResult> executeResult(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async => const ToolExecutionResult.success('written');
}

/// 第一轮请求工具,第二轮结束;非流式请求由真实 AI 审核器发起。
class _ToolCompletionService extends ChatCompletionsService {
  _ToolCompletionService() : super(llmClient: LlmClient());

  final List<String> reviews = [];
  String reviewDecision = 'allow';
  String? reviewResponse;
  void Function()? duringReview;
  String toolName = 'bash';
  Map<String, dynamic> arguments = {'command': 'git status'};
  int callCount = 1;
  String? nextToolName;
  Map<String, dynamic> nextArguments = {};
  int _turn = 0;

  @override
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
    ResponseFormat? responseFormat,
    Future<void>? cancelSignal,
    int? outputRoom,
  }) async* {
    final turn = _turn++;
    final first = turn == 0 || (turn == 1 && nextToolName != null);
    yield ChatStreamEvent.fromJson({
      'id': 'test',
      'object': 'chat.completion.chunk',
      'created': 0,
      'model': 'test',
      'choices': [
        {
          'index': 0,
          'delta': first
              ? {
                  'tool_calls': [
                    for (var i = 0; i < callCount; i++)
                      {
                        'index': i,
                        'id': 'tool-call-$turn-$i',
                        'type': 'function',
                        'function': {
                          'name': turn == 0 ? toolName : nextToolName,
                          'arguments': jsonEncode({
                            ...(turn == 0 ? arguments : nextArguments),
                            'call_description': '查看仓库状态',
                          }),
                        },
                      },
                  ],
                }
              : {'content': 'done'},
          'finish_reason': first ? 'tool_calls' : 'stop',
        },
      ],
    });
  }

  @override
  Future<String> complete({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    Future<void>? cancelSignal,
  }) async {
    reviews.add(jsonEncode(messages.map((m) => m.toJson()).toList()));
    duringReview?.call();
    return reviewResponse ??
        jsonEncode({'decision': reviewDecision, 'reason': '测试审批结果'});
  }
}
