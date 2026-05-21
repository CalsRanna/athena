# Athena Agent 转型实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Athena 从聊天助手转型为具备内置工具调用与 Skill 系统的 AI Agent。

**Architecture:** 在现有分层基础上新增 `lib/agent/` 层，包含 AgentService 编排循环、ToolRegistry 工具注册、PermissionService 权限控制、以及 Skill 加载系统。ChatMessageService 扩展为支持 tools 参数与 tool_calls delta 解析。MessageEntity 新增 tool_calls/tool_results 字段。

**Tech Stack:** Flutter + Dart, openai_dart (v5.0.0+), signals, get_it, laconic (SQLite)

---

## 前置步骤：确认依赖版本

- [ ] **Step 1: 运行 flutter pub get 确认 openai_dart 版本**

当前 `.dart_tool/package_config.json` 中 `openai_dart` 实际解析到 v0.4.5，但 `pubspec.yaml` 声明为 `^5.0.0`。运行 pub get 拉取正确版本。

```bash
cd /Users/cals/Spare/athena && flutter pub get
```

- [ ] **Step 2: 确认 openai_dart 的 Tool API**

验证 ChatCompletionCreateRequest 中 `tools` 参数、ChatDelta 中 `toolCalls`、ChatMessage 中 `tool()` 和 `assistant(toolCalls:)` 构造器可用。

```bash
grep -r "tools\|toolCalls\|Tool.function" /Users/cals/.pub-cache/hosted/pub.dev/openai_dart-*/lib/src/models/chat/ | head -20
```

Expected: `ChatCompletionCreateRequest` 有 `tools` 字段, `ChatMessage` 有 `tool()` 工厂方法, `ToolCall` 类型存在。

---

## Phase 1: 基础设施

### Task 1.1: Tool 抽象接口

**Files:**
- Create: `lib/agent/tool/tool_interface.dart`

- [ ] **Step 1: 创建 Tool 接口与 DangerLevel 枚举**

```dart
// lib/agent/tool/tool_interface.dart

enum DangerLevel { safe, needsApproval, forbidden }

abstract class Tool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters; // JSON Schema
  DangerLevel get dangerLevel;

  Future<String> execute(Map<String, dynamic> args);
}
```

- [ ] **Step 2: 验证语法**

```bash
cd /Users/cals/Spare/athena && flutter analyze lib/agent/tool/tool_interface.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/tool/tool_interface.dart
git commit -m "feat(agent): add Tool interface and DangerLevel enum"
```

### Task 1.2: ToolRegistry

**Files:**
- Create: `lib/agent/tool/tool_registry.dart`

- [ ] **Step 1: 创建 ToolRegistry**

```dart
// lib/agent/tool/tool_registry.dart

import 'tool_interface.dart';

class ToolRegistry {
  final Map<String, Tool> _tools = {};

  void register(Tool tool) {
    _tools[tool.name] = tool;
  }

  void registerAll(Iterable<Tool> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

  Tool? get(String name) => _tools[name];

  List<Tool> get all => _tools.values.toList();

  List<Map<String, dynamic>> get definitions => _tools.values.map((t) => {
    'type': 'function',
    'function': {
      'name': t.name,
      'description': t.description,
      'parameters': t.parameters,
    },
  }).toList();
}
```

- [ ] **Step 2: 验证语法**

```bash
flutter analyze lib/agent/tool/tool_registry.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/tool/tool_registry.dart
git commit -m "feat(agent): add ToolRegistry"
```

### Task 1.3: SearchTool

**Files:**
- Create: `lib/agent/tool/search_tool.dart`

- [ ] **Step 1: 实现 SearchTool（grep + find）**

```dart
// lib/agent/tool/search_tool.dart

import 'dart:convert';
import 'dart:io';

import 'tool_interface.dart';

class SearchTool implements Tool {
  @override
  String get name => 'search';

  @override
  String get description => 'Search for files by pattern (find) or search file '
      'contents with regex (grep). Use when you need to locate files or code.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'pattern': {
        'type': 'string',
        'description': 'The search pattern (file name glob for find, '
            'regex for grep in content).',
      },
      'path': {
        'type': 'string',
        'description': 'The directory path to search in. Defaults to the '
            'current working directory.',
      },
      'type': {
        'type': 'string',
        'enum': ['grep', 'find'],
        'description': 'Search type: "grep" searches file contents, '
            '"find" searches file names.',
      },
    },
    'required': ['pattern'],
  };

  @override
  DangerLevel get dangerLevel => DangerLevel.safe;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final pattern = args['pattern'] as String;
    final path = args['path'] as String? ?? Directory.current.path;
    final type = args['type'] as String? ?? 'grep';

    final results = await Process.run(
      type == 'find' ? 'find' : 'grep',
      type == 'find'
          ? [path, '-name', pattern, '-not', '-path', '*/\\.*']
          : ['-rn', '--include=*.{dart,yaml,md,json}', pattern, path],
    );

    final output = '${results.stdout}'.trim();
    if (output.isEmpty) return 'No results found for "$pattern"';

    // Truncate to avoid context overflow
    final lines = output.split('\n');
    if (lines.length > 50) {
      return '${lines.take(50).join('\n')}\n\n... and ${lines.length - 50} more results';
    }
    return output;
  }
}
```

- [ ] **Step 2: 验证语法**

```bash
flutter analyze lib/agent/tool/search_tool.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/tool/search_tool.dart
git commit -m "feat(agent): add SearchTool (grep + find)"
```

### Task 1.4: FileReadTool

**Files:**
- Create: `lib/agent/tool/file_read_tool.dart`

- [ ] **Step 1: 实现 FileReadTool**

```dart
// lib/agent/tool/file_read_tool.dart

import 'dart:io';

import 'tool_interface.dart';

class FileReadTool implements Tool {
  @override
  String get name => 'file_read';

  @override
  String get description => 'Read the contents of a file. '
      'Use when you need to examine a file\'s contents.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'path': {
        'type': 'string',
        'description': 'The path to the file to read.',
      },
      'offset': {
        'type': 'integer',
        'description': 'Line number to start reading from (0-indexed). '
            'Optional, defaults to 0.',
      },
      'limit': {
        'type': 'integer',
        'description': 'Maximum number of lines to read. Optional.',
      },
    },
    'required': ['path'],
  };

  @override
  DangerLevel get dangerLevel => DangerLevel.safe;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final offset = args['offset'] as int? ?? 0;
    final limit = args['limit'] as int?;

    final file = File(path);
    if (!await file.exists()) {
      return 'Error: File not found: $path';
    }

    final lines = await file.readAsLines();
    final start = offset.clamp(0, lines.length);
    final end = limit != null
        ? (start + limit).clamp(start, lines.length)
        : lines.length;

    final selected = lines.sublist(start, end);
    // Format with line numbers
    final buffer = StringBuffer();
    for (var i = 0; i < selected.length; i++) {
      buffer.writeln('${start + i + 1}\t${selected[i]}');
    }
    return buffer.toString();
  }
}
```

- [ ] **Step 2: 验证语法**

```bash
flutter analyze lib/agent/tool/file_read_tool.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/tool/file_read_tool.dart
git commit -m "feat(agent): add FileReadTool"
```

### Task 1.5: ShellTool（基础版）

**Files:**
- Create: `lib/agent/tool/shell_tool.dart`

- [ ] **Step 1: 实现 ShellTool**

```dart
// lib/agent/tool/shell_tool.dart

import 'dart:io';

import 'tool_interface.dart';

class ShellTool implements Tool {
  @override
  String get name => 'shell';

  @override
  String get description => 'Execute a shell command. '
      'Use when you need to run terminal commands like git, npm, dart, etc. '
      'Commands run in the current working directory.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'command': {
        'type': 'string',
        'description': 'The shell command to execute.',
      },
      'timeout': {
        'type': 'integer',
        'description': 'Timeout in seconds. Defaults to 30.',
      },
    },
    'required': ['command'],
  };

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final command = args['command'] as String;
    final timeoutSeconds = args['timeout'] as int? ?? 30;

    try {
      final result = await Process.run(
        '/bin/sh',
        ['-c', command],
        workingDirectory: Directory.current.path,
      ).timeout(Duration(seconds: timeoutSeconds));

      final stdout = '${result.stdout}'.trim();
      final stderr = '${result.stderr}'.trim();
      final buffer = StringBuffer();
      if (stdout.isNotEmpty) {
        buffer.writeln(stdout);
      }
      if (stderr.isNotEmpty) {
        buffer.writeln('[stderr]');
        buffer.writeln(stderr);
      }
      buffer.writeln('[exit code: ${result.exitCode}]');
      return buffer.toString().trim();
    } catch (e) {
      return 'Error executing command: $e';
    }
  }
}
```

- [ ] **Step 2: 验证语法**

```bash
flutter analyze lib/agent/tool/shell_tool.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/tool/shell_tool.dart
git commit -m "feat(agent): add ShellTool (basic)"
```

### Task 1.6: MessageEntity 数据库迁移

**Files:**
- Create: `lib/database/migration/migration_202605210001_add_tool_fields_to_messages.dart`
- Modify: `lib/entity/message_entity.dart`
- Modify: `lib/database/database.dart`

- [ ] **Step 1: 创建迁移文件**

```dart
// lib/database/migration/migration_202605210001_add_tool_fields_to_messages.dart

import 'package:athena/database/database.dart';

class Migration202605210001AddToolFieldsToMessages {
  static const name = 'migration_202605210001_add_tool_fields_to_messages';

  Future<void> migrate() async {
    final laconic = Database.instance.laconic;

    final count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.statement('''
      ALTER TABLE messages ADD COLUMN tool_calls TEXT DEFAULT ''
    ''');

    await laconic.statement('''
      ALTER TABLE messages ADD COLUMN tool_results TEXT DEFAULT ''
    ''');

    await laconic.table('migrations').insert([
      {'name': name},
    ]);
  }
}
```

- [ ] **Step 2: 注册迁移**

在 `lib/database/database.dart` 的 `_migrate()` 方法末尾，`Migration202511280001FixModelsSchemaTypes` 之后添加：

```dart
await Migration202605210001AddToolFieldsToMessages().migrate();
```

并在文件顶部添加 import：

```dart
import 'package:athena/database/migration/migration_202605210001_add_tool_fields_to_messages.dart';
```

- [ ] **Step 3: 更新 MessageEntity**

在 `lib/entity/message_entity.dart` 中新增字段：

```dart
// 在 existing fields 后添加
final String toolCalls;
final String toolResults;
```

更新构造函数，在 `this.reference = '',` 之后：

```dart
this.toolCalls = '',
this.toolResults = '',
```

更新 `fromJson`：

```dart
toolCalls: json.getString('tool_calls'),
toolResults: json.getString('tool_results'),
```

更新 `toJson`：

```dart
'tool_calls': toolCalls,
'tool_results': toolResults,
```

更新 `copyWith`：

```dart
String? toolCalls,
String? toolResults,
```

以及 copyWith 中的赋值：

```dart
toolCalls: toolCalls ?? this.toolCalls,
toolResults: toolResults ?? this.toolResults,
```

- [ ] **Step 4: 验证分析通过**

```bash
flutter analyze lib/entity/message_entity.dart lib/database/database.dart lib/database/migration/migration_202605210001_add_tool_fields_to_messages.dart
```

Expected: No issues found.

- [ ] **Step 5: 提交**

```bash
git add lib/database/migration/migration_202605210001_add_tool_fields_to_messages.dart lib/entity/message_entity.dart lib/database/database.dart
git commit -m "feat(agent): add tool_calls and tool_results fields to messages table"
```

---

## Phase 2: Agent 循环

### Task 2.1: AgentService 核心编排

**Files:**
- Create: `lib/agent/agent_service.dart`

- [ ] **Step 1: 创建 AgentService（第一版：文本 + 工具调用循环）**

```dart
// lib/agent/agent_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:athena/agent/tool/tool_interface.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/service/chat_service.dart';
import 'package:openai_dart/openai_dart.dart';

class AgentService {
  final ChatService _chatService;
  final MessageRepository _messageRepository;
  final ToolRegistry _toolRegistry;

  AgentService({
    ChatService? chatService,
    MessageRepository? messageRepository,
    ToolRegistry? toolRegistry,
  })  : _chatService = chatService ?? ChatService(),
        _messageRepository = messageRepository ?? MessageRepository(),
        _toolRegistry = toolRegistry ?? ToolRegistry();

  static const int maxIterations = 10;

  /// 执行 Agent 循环，返回流式的 Agent 事件
  Stream<AgentEvent> run({
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> baseMessages,
    String? skillPrompt,
  }) async* {
    var messages = List<ChatMessage>.from(baseMessages);
    final tools = _toolRegistry.definitions;

    for (var iteration = 0; iteration < maxIterations; iteration++) {
      // 1. 注入 skill prompt（如果有的话，且只在第一轮）
      if (iteration == 0 && skillPrompt != null && skillPrompt.isNotEmpty) {
        messages = [
          ChatMessage.system(skillPrompt),
          ...messages,
        ];
      }

      // 2. 调用 LLM stream
      final accumulator = ChatStreamAccumulator();
      final request = ChatCompletionCreateRequest(
        model: model.modelId,
        messages: messages,
        tools: tools.isNotEmpty
            ? tools.map((t) => Tool.function(
                  name: t['function']['name'] as String,
                  description: t['function']['description'] as String,
                  parameters: t['function']['parameters'] as Map<String, dynamic>,
                )).toList()
            : null,
      );

      final stream = _chatService.getCompletion(
        chat: chat,
        messages: messages,
        provider: provider,
        model: model,
      );

      await for (final chunk in stream) {
        accumulator.add(chunk);

        // 文本内容实时输出
        final textDelta = chunk.textDelta;
        if (textDelta != null && textDelta.isNotEmpty) {
          yield AgentEvent.text(textDelta);
        }
      }

      // 3. 检查工具调用
      final toolCalls = accumulator.toolCalls;

      if (toolCalls.isEmpty) {
        // 无工具调用，流程结束
        final fullContent = accumulator.content;
        yield AgentEvent.done(content: fullContent);
        return;
      }

      // 4. 有工具调用，输出工具调用事件
      final toolCallDataList = <Map<String, dynamic>>[];
      for (final tc in toolCalls) {
        yield AgentEvent.toolCall(
          id: tc.id,
          name: tc.function.name,
          arguments: tc.function.arguments,
        );
      }

      // 5. 构建 assistant message（含 tool calls）
      messages.add(ChatMessage.assistant(
        content: accumulator.content.isNotEmpty ? accumulator.content : null,
        toolCalls: toolCalls,
      ));

      // 6. 执行工具并将结果注入 messages
      for (final tc in toolCalls) {
        Map<String, dynamic> args;
        try {
          args = jsonDecode(tc.function.arguments) as Map<String, dynamic>;
        } catch (_) {
          args = {};
        }

        // PermissionService 检查（Phase 3 加入，目前直接执行）
        final tool = _toolRegistry.get(tc.function.name);
        final result = tool != null
            ? await tool.execute(args)
            : 'Error: Unknown tool "${tc.function.name}"';

        yield AgentEvent.toolResult(
          id: tc.id,
          name: tc.function.name,
          result: result,
        );

        messages.add(ChatMessage.tool(
          toolCallId: tc.id,
          content: result,
        ));

        toolCallDataList.add({
          'id': tc.id,
          'name': tc.function.name,
          'arguments': tc.function.arguments,
          'result': result,
        });
      }

      // 7. 发出迭代完成事件，UI 可保存中间状态
      yield AgentEvent.iterationComplete(
        toolCalls: toolCallDataList,
        content: accumulator.content,
      );
    }
  }
}

/// Agent 流式事件
sealed class AgentEvent {
  const AgentEvent();

  const factory AgentEvent.text(String delta) = AgentTextEvent;

  const factory AgentEvent.toolCall({
    required String id,
    required String name,
    required String arguments,
  }) = AgentToolCallEvent;

  const factory AgentEvent.toolResult({
    required String id,
    required String name,
    required String result,
  }) = AgentToolResultEvent;

  const factory AgentEvent.iterationComplete({
    required List<Map<String, dynamic>> toolCalls,
    required String content,
  }) = AgentIterationCompleteEvent;

  const factory AgentEvent.done({required String content}) = AgentDoneEvent;
}

class AgentTextEvent extends AgentEvent {
  final String delta;
  const AgentTextEvent(this.delta);
}

class AgentToolCallEvent extends AgentEvent {
  final String id;
  final String name;
  final String arguments;
  const AgentToolCallEvent({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

class AgentToolResultEvent extends AgentEvent {
  final String id;
  final String name;
  final String result;
  const AgentToolResultEvent({
    required this.id,
    required this.name,
    required this.result,
  });
}

class AgentIterationCompleteEvent extends AgentEvent {
  final List<Map<String, dynamic>> toolCalls;
  final String content;
  const AgentIterationCompleteEvent({
    required this.toolCalls,
    required this.content,
  });
}

class AgentDoneEvent extends AgentEvent {
  final String content;
  const AgentDoneEvent({required this.content});
}
```

- [ ] **Step 2: 验证分析通过**

```bash
flutter analyze lib/agent/agent_service.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/agent_service.dart
git commit -m "feat(agent): add AgentService with tool-calling loop"
```

### Task 2.2: ChatService 适配 tools 参数

**Files:**
- Modify: `lib/service/chat_service.dart`

- [ ] **Step 1: 为 getCompletion 添加 tools 参数支持**

修改 `ChatService.getCompletion()` 方法签名，支持传入 tools：

```dart
// lib/service/chat_service.dart

Stream<ChatStreamEvent> getCompletion({
  required ChatEntity chat,
  required List<ChatMessage> messages,
  required ProviderEntity provider,
  required ModelEntity model,
  List<Tool>? tools,  // 新增
}) async* {
  var client = OpenAIClient.withApiKey(
    provider.apiKey,
    baseUrl: provider.baseUrl,
    defaultHeaders: {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    },
  );
  var request = ChatCompletionCreateRequest(
    model: model.modelId,
    messages: messages,
    temperature: chat.temperature,
    tools: tools,  // 新增
  );
  yield* client.chat.completions.createStream(request);
}
```

- [ ] **Step 2: 同步更新 ChatMessageService.getCompletionStream**

```dart
// lib/service/chat_message_service.dart

Stream<ChatStreamEvent> getCompletionStream({
  required ChatEntity chat,
  required List<ChatMessage> messages,
  required ProviderEntity provider,
  required ModelEntity model,
  List<Tool>? tools,  // 新增
}) {
  return _chatService.getCompletion(
    chat: chat,
    messages: messages,
    provider: provider,
    model: model,
    tools: tools,  // 新增
  );
}
```

- [ ] **Step 3: 验证**

```bash
flutter analyze lib/service/chat_service.dart lib/service/chat_message_service.dart
```

Expected: No issues found.

- [ ] **Step 4: 提交**

```bash
git add lib/service/chat_service.dart lib/service/chat_message_service.dart
git commit -m "feat(agent): add tools parameter to chat completion"
```

### Task 2.3: ChatViewModel 集成 AgentService

**Files:**
- Modify: `lib/view_model/chat_view_model.dart`

- [ ] **Step 1: 重构 sendMessage 使用 AgentService**

修改 `sendMessage` 方法，引入 `AgentService` 编排：

```dart
// lib/view_model/chat_view_model.dart

// 新增 import
import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/tool/file_read_tool.dart';
import 'package:athena/agent/tool/search_tool.dart';
import 'package:athena/agent/tool/shell_tool.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'dart:convert';

// 新增字段
final _agentService = AgentService(
  toolRegistry: ToolRegistry()
    ..registerAll([
      SearchTool(),
      FileReadTool(),
      ShellTool(),
    ]),
);

// sendMessage 方法改动核心部分（仅替换 stream 处理段，其他不变）：

// 原代码段 "// 5. 流式获取并更新 UI":
//
// 替换为以下 AgentService 流式处理:

// 4. 创建 assistant 消息占位（与原来相同）
var assistantMessage = MessageEntity(
  chatId: chat.id!,
  role: 'assistant',
  content: '',
);
assistantId = await _messageRepository.storeMessage(assistantMessage);
assistantMessage = assistantMessage.copyWith(id: assistantId);
messages.value = [...messages.value, assistantMessage];

// 5. AgentService 编排
var toolCallsJson = <Map<String, dynamic>>[];
var toolResultsJson = <Map<String, dynamic>>[];

var agentStream = _agentService.run(
  chat: chat,
  provider: provider,
  model: model,
  baseMessages: wrappedMessages,
);

await for (final event in agentStream) {
  if (event is AgentTextEvent) {
    contentBuffer.write(event.delta);
    assistantMessage = assistantMessage.copyWith(
      content: contentBuffer.toString(),
    );
    _updateMessageInList(assistantId, assistantMessage);
  } else if (event is AgentToolCallEvent) {
    toolCallsJson.add({
      'id': event.id,
      'name': event.name,
      'arguments': event.arguments,
    });
    assistantMessage = assistantMessage.copyWith(
      toolCalls: jsonEncode(toolCallsJson),
    );
    _updateMessageInList(assistantId, assistantMessage);
  } else if (event is AgentToolResultEvent) {
    toolResultsJson.add({
      'id': event.id,
      'name': event.name,
      'result': event.result,
    });
    assistantMessage = assistantMessage.copyWith(
      toolResults: jsonEncode(toolResultsJson),
    );
    _updateMessageInList(assistantId, assistantMessage);
  } else if (event is AgentDoneEvent) {
    assistantMessage = assistantMessage.copyWith(
      content: event.content,
    );
    _updateMessageInList(assistantId, assistantMessage);
  }
}

// 6. 保存最终消息并更新时间戳（与原来相同）
await _messageRepository.updateMessage(assistantMessage);
await _updateChatTimestamp(chat);
await getChats();
```

- [ ] **Step 2: 验证**

```bash
flutter analyze lib/view_model/chat_view_model.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/view_model/chat_view_model.dart
git commit -m "feat(agent): integrate AgentService into ChatViewModel"
```

### Task 2.4: 工具调用 UI 卡片

**Files:**
- Create: `lib/page/desktop/home/component/tool_call_card.dart`
- Create: `lib/page/desktop/home/component/tool_result_card.dart`
- Modify: `lib/component/message_list_tile.dart`

- [ ] **Step 1: 创建工具调用卡片组件**

```dart
// lib/page/desktop/home/component/tool_call_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

class ToolCallCard extends StatelessWidget {
  final String toolName;
  final String arguments;
  final bool loading;

  const ToolCallCard({
    super.key,
    required this.toolName,
    required this.arguments,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            loading ? HugeIcons.strokeRoundedLoading02 : HugeIcons.strokeRoundedTools,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toolName,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  arguments,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 创建工具结果卡片组件**

```dart
// lib/page/desktop/home/component/tool_result_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

class ToolResultCard extends StatefulWidget {
  final String toolName;
  final String result;
  final bool isError;

  const ToolResultCard({
    super.key,
    required this.toolName,
    required this.result,
    this.isError = false,
  });

  @override
  State<ToolResultCard> createState() => _ToolResultCardState();
}

class _ToolResultCardState extends State<ToolResultCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isError = widget.result.startsWith('Error:');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isError
            ? Colors.red.shade50
            : Colors.green.shade50,
        border: Border.all(
          color: isError ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(
                  isError ? HugeIcons.strokeRoundedCancel01 : HugeIcons.strokeRoundedCheckmarkCircle02,
                  size: 16,
                  color: isError ? Colors.red.shade600 : Colors.green.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.toolName,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isError ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? HugeIcons.strokeRoundedArrowUp01 : HugeIcons.strokeRoundedArrowDown01,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.white.withValues(alpha: 0.7),
              ),
              child: Text(
                widget.result,
                maxLines: 15,
                style: GoogleFonts.firaCode(fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 在 MessageListTile 中集成工具卡片**

修改 `lib/component/message_list_tile.dart` 的 `_AssistantMessageListTile._buildContent()`：

```dart
// 在 _buildContent 方法中，AthenaMarkdown 之前插入工具卡片逻辑：

Widget _buildContent() {
  final message = this.message;
  final hasToolCalls = message.toolCalls.isNotEmpty;
  final hasToolResults = message.toolResults.isNotEmpty;

  final toolCards = <Widget>[];
  if (hasToolCalls) {
    try {
      final calls = jsonDecode(message.toolCalls) as List<dynamic>;
      for (final call in calls) {
        toolCards.add(ToolCallCard(
          toolName: call['name'] ?? '',
          arguments: call['arguments'] ?? '',
          loading: !hasToolResults,  // 有结果前显示 loading 状态
        ));
      }
    } catch (_) {}
  }
  if (hasToolResults) {
    try {
      final results = jsonDecode(message.toolResults) as List<dynamic>;
      for (final result in results) {
        toolCards.add(ToolResultCard(
          toolName: result['name'] ?? '',
          result: result['result'] ?? '',
        ));
      }
    } catch (_) {}
  }

  var children = [
    _AssistantMessageListTileThinkingPart(message: message),
    if (message.content.isNotEmpty) SizedBox(height: 8),
    AthenaMarkdown(engine: AthenaMarkdownEngine.flutter, message: message),
    ...toolCards,  // 插入工具卡片
    _AssistantMessageListTileReferencePart(message: message),
    _AssistantMessageListTileLoadingPart(loading: loading, message: message),
  ];
  var column = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  );
  var container = Container(
    alignment: Alignment.centerLeft,
    constraints: const BoxConstraints(minHeight: 36),
    child: column,
  );
  return Expanded(child: container);
}
```

在文件顶部添加 import：

```dart
import 'dart:convert';
import 'package:athena/page/desktop/home/component/tool_call_card.dart';
import 'package:athena/page/desktop/home/component/tool_result_card.dart';
```

- [ ] **Step 4: 验证**

```bash
flutter analyze lib/page/desktop/home/component/tool_call_card.dart lib/page/desktop/home/component/tool_result_card.dart lib/component/message_list_tile.dart
```

Expected: No issues found.

- [ ] **Step 5: 提交**

```bash
git add lib/page/desktop/home/component/tool_call_card.dart lib/page/desktop/home/component/tool_result_card.dart lib/component/message_list_tile.dart
git commit -m "feat(agent): add tool call and result UI cards"
```

---

## Phase 3: 权限系统

### Task 3.1: PermissionService

**Files:**
- Create: `lib/agent/permission/permission_service.dart`

- [ ] **Step 1: 创建 PermissionService**

```dart
// lib/agent/permission/permission_service.dart

import 'package:athena/agent/tool/tool_interface.dart';

/// 在一次对话会话内记住的用户权限选择
enum PermissionChoice { allowOnce, allowSession, deny }

class PermissionService {
  /// 会话级已批准操作缓存（key = toolName:command/path）
  final Map<String, PermissionChoice> _sessionCache = {};

  /// 判断是否需要用户审批
  /// 返回 null = 自动允许, PermissionChoice = 需要用户选择
  Future<PermissionChoice?> check({
    required Tool tool,
    required Map<String, dynamic> args,
    String? skillAllowedTools,
  }) async {
    // 1. forbidden 工具直接拒绝
    if (tool.dangerLevel == DangerLevel.forbidden) {
      return PermissionChoice.deny;
    }

    // 2. safe 工具自动放行
    if (tool.dangerLevel == DangerLevel.safe) {
      return null; // null 表示自动允许
    }

    // 3. 检查 skill allowed-tools（如果当前有活跃 skill）
    if (skillAllowedTools != null) {
      final allowed = _parseAllowedTools(skillAllowedTools);
      if (allowed.any((a) => _matchesTool(a, tool.name, args))) {
        return null; // skill 声明了此工具免审批
      }
    }

    // 4. 检查会话缓存
    final key = _cacheKey(tool, args);
    final cached = _sessionCache[key];
    if (cached == PermissionChoice.allowSession) return null;

    // 5. needsApproval - 需要用户确认
    return null; // 表示待确认（实际 UI 由 ChatViewModel 处理）
  }

  void rememberChoice({
    required Tool tool,
    required Map<String, dynamic> args,
    required PermissionChoice choice,
  }) {
    final key = _cacheKey(tool, args);
    _sessionCache[key] = choice;
  }

  void clearSessionCache() {
    _sessionCache.clear();
  }

  String _cacheKey(Tool tool, Map<String, dynamic> args) {
    final arg = args.containsKey('command')
        ? args['command']
        : args['path'] ?? '';
    return '${tool.name}:$arg';
  }

  /// 解析 skill 的 allowed-tools 字段
  List<String> _parseAllowedTools(String allowedTools) {
    return allowedTools
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 检查工具是否匹配 allowed-tools 模式
  bool _matchesTool(String pattern, String toolName, Map<String, dynamic> args) {
    // "Bash(git *)" vs "shell" with command="git diff"
    if (pattern.startsWith('Bash(')) {
      if (toolName != 'shell' && toolName != 'bash') return false;
      final inner = pattern.substring(5, pattern.length - 1).trim();
      final command = args['command'] as String? ?? '';
      return _matchBashPattern(inner, command);
    }
    // 直接工具名匹配
    return pattern == toolName;
  }

  bool _matchBashPattern(String pattern, String command) {
    if (pattern == '*') return true;
    if (pattern.endsWith('*')) {
      return command.startsWith(pattern.substring(0, pattern.length - 1));
    }
    return command == pattern;
  }
}
```

- [ ] **Step 2: 验证**

```bash
flutter analyze lib/agent/permission/permission_service.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/permission/permission_service.dart
git commit -m "feat(agent): add PermissionService with session caching"
```

### Task 3.2: 审批弹窗

**Files:**
- Create: `lib/page/desktop/home/component/approval_dialog.dart`

- [ ] **Step 1: 创建审批弹窗**

```dart
// lib/page/desktop/home/component/approval_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals/signals.dart';

enum ApprovalResult { approve, approveOnce, deny }

class ApprovalDialog extends StatefulWidget {
  final String toolName;
  final String description;

  const ApprovalDialog({
    super.key,
    required this.toolName,
    required this.description,
  });

  @override
  State<ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<ApprovalDialog> {
  final rememberChoice = signal(false);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(HugeIcons.strokeRoundedAlert02, size: 20, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(widget.toolName, style: GoogleFonts.firaCode(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade100,
              ),
              child: Text(
                widget.description,
                style: GoogleFonts.firaCode(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Watch((context) {
              return CheckboxListTile(
                value: rememberChoice.value,
                onChanged: (v) => rememberChoice.value = v ?? false,
                title: Text(
                  'Remember choice for this session',
                  style: TextStyle(fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ApprovalResult.deny),
          child: const Text('Deny'),
        ),
        ElevatedButton(
          onPressed: () {
            final result = rememberChoice.value
                ? ApprovalResult.approve
                : ApprovalResult.approveOnce;
            Navigator.pop(context, result);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 验证**

```bash
flutter analyze lib/page/desktop/home/component/approval_dialog.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/page/desktop/home/component/approval_dialog.dart
git commit -m "feat(agent): add approval dialog"
```

### Task 3.3: ChatViewModel 集成权限检查

**Files:**
- Modify: `lib/view_model/chat_view_model.dart`
- Create: `lib/agent/permission/sandbox.dart`

- [ ] **Step 1: 创建 PathSandbox**

```dart
// lib/agent/permission/sandbox.dart

import 'dart:io';

class PathSandbox {
  final List<String> allowedPaths;
  final List<String> deniedPaths;

  PathSandbox({
    List<String>? allowedPaths,
    List<String>? deniedPaths,
  })  : allowedPaths = allowedPaths ?? [Directory.current.path],
        deniedPaths = deniedPaths ?? [
          '${_home}/.ssh',
          '${_home}/.aws',
          '/etc',
          '/System',
        ];

  static String get _home {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/';
    return home;
  }

  bool canRead(String path) {
    final resolved = _resolve(path);
    if (_isDenied(resolved)) return false;
    return _isAllowed(resolved);
  }

  bool canWrite(String path) {
    final resolved = _resolve(path);
    if (_isDenied(resolved)) return false;
    return _isAllowed(resolved);
  }

  bool canExecute(String command) {
    // 检查命令是否包含明显的恶意模式（基础防护）
    final dangerous = ['rm -rf /', 'sudo ', 'chmod 777 /', 'mkfs.'];
    return !dangerous.any((d) => command.contains(d));
  }

  bool _isAllowed(String path) {
    return allowedPaths.any((a) => path.startsWith(_resolve(a)));
  }

  bool _isDenied(String path) {
    return deniedPaths.any((d) => path.startsWith(_resolve(d)));
  }

  String _resolve(String path) {
    if (path.startsWith('~/')) {
      return '$_home/${path.substring(2)}';
    }
    if (path.startsWith('/')) return path;
    return '${Directory.current.path}/$path';
  }
}
```

- [ ] **Step 2: 验证**

```bash
flutter analyze lib/agent/permission/sandbox.dart
```

Expected: No issues found.

- [ ] **Step 3: 在 ChatViewModel 的 AgentService 事件处理中集成权限**

在 `ChatViewModel.sendMessage` 中处理 `AgentToolCallEvent` 时，调用 PermissionService 并弹出审批框。此处改动需要 home_page.dart 配合传入 BuildContext。

实际上，权限检查应该在 AgentService.run() 中处理。但 AgentService 不持有 BuildContext。因此采用回调模式：AgentService 在需要执行工具前发出事件，ChatViewModel 负责弹窗审批。

当前 Phase 2 的设计已通过在流中发出 `AgentToolCallEvent` 和等待 AgentService 内部执行来支持这一点。Phase 3 改为：

AgentService 发出 `AgentToolCallEvent` 后，**不自动执行工具**，而是暂停并等待外部批准信号。但这样会让 API 变得复杂（需要双向通信）。

简化方案：Phase 3 中，`AgentService.run()` 方法接受一个 `PermissionCallback`：

```dart
typedef PermissionCallback = Future<bool> Function(String toolName, String description);

class AgentService {
  // ...
  Stream<AgentEvent> run({
    // ... existing params
    PermissionCallback? onPermission,
  }) async* {
    // 在工具执行前：
    if (onPermission != null && tool.dangerLevel == DangerLevel.needsApproval) {
      final approved = await onPermission(tool.name, args.values.join(' '));
      if (!approved) {
        yield AgentEvent.toolResult(
          id: tc.id,
          name: tc.function.name,
          result: 'User denied the tool execution.',
        );
        continue;
      }
    }
  }
}
```

在 ChatViewModel 中传入回调，回调中弹出 approval_dialog 并等待用户选择。

此步不在此单独实现，而是在 Task 3.3 整体提交。

- [ ] **Step 4: 提交**

```bash
git add lib/agent/permission/sandbox.dart lib/agent/agent_service.dart lib/view_model/chat_view_model.dart
git commit -m "feat(agent): integrate permission checks into agent loop"
```

---

## Phase 4: Skill 系统

### Task 4.1: SkillLoader

**Files:**
- Create: `lib/agent/skill/skill_loader.dart`

- [ ] **Step 1: 创建 Skill 数据模型与加载器**

```dart
// lib/agent/skill/skill_loader.dart

import 'dart:io';

class Skill {
  final String name;
  final String description;
  final String body;
  final String? allowedTools;
  final bool disableModelInvocation;
  final String sourcePath;

  const Skill({
    required this.name,
    required this.description,
    required this.body,
    this.allowedTools,
    this.disableModelInvocation = false,
    required this.sourcePath,
  });
}

class SkillLoader {
  /// 从目录中加载所有 Skill
  List<Skill> loadFromDirectory(String directoryPath) {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return [];

    final skills = <Skill>[];
    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;
      final skillFile = File('${entity.path}/SKILL.md');
      if (!skillFile.existsSync()) continue;
      try {
        final skill = _parseSkill(skillFile);
        if (skill != null) skills.add(skill);
      } catch (_) {
        // Skip invalid skill directories
      }
    }
    return skills;
  }

  Skill? _parseSkill(File file) {
    final content = file.readAsStringSync();
    final lines = content.split('\n');

    // 解析 YAML frontmatter (在 --- 之间)
    if (lines.isEmpty || lines.first.trim() != '---') return null;

    var endIndex = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        endIndex = i;
        break;
      }
    }
    if (endIndex == -1) return null;

    final frontmatter = lines.sublist(1, endIndex).join('\n');
    final body = lines.sublist(endIndex + 1).join('\n').trim();

    final name = _extractField(frontmatter, 'name');
    final description = _extractField(frontmatter, 'description');
    if (name.isEmpty || description.isEmpty) return null;

    return Skill(
      name: name,
      description: description,
      body: body,
      allowedTools: _extractFieldOrNull(frontmatter, 'allowed-tools'),
      disableModelInvocation:
          _extractField(frontmatter, 'disable-model-invocation') == 'true',
      sourcePath: file.parent.path,
    );
  }

  String _extractField(String yaml, String key) {
    final regex = RegExp('^$key:\\s*(.+)\$', multiLine: true);
    final match = regex.firstMatch(yaml);
    return match?.group(1)?.trim() ?? '';
  }

  String? _extractFieldOrNull(String yaml, String key) {
    final value = _extractField(yaml, key);
    return value.isEmpty ? null : value;
  }
}
```

- [ ] **Step 2: 验证**

```bash
flutter analyze lib/agent/skill/skill_loader.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/skill/skill_loader.dart
git commit -m "feat(agent): add SkillLoader for parsing SKILL.md files"
```

### Task 4.2: SkillRegistry

**Files:**
- Create: `lib/agent/skill/skill_registry.dart`

- [ ] **Step 1: 创建 SkillRegistry**

```dart
// lib/agent/skill/skill_registry.dart

import 'dart:io';

import 'package:athena/agent/skill/skill_loader.dart';

class SkillRegistry {
  final SkillLoader _loader = SkillLoader();
  final Map<String, Skill> _skills = {};

  /// 扫描并加载所有 Skill
  void loadAll() {
    _skills.clear();

    // 项目级 skills
    final projectPath = '${Directory.current.path}/.athena/skills';
    for (final skill in _loader.loadFromDirectory(projectPath)) {
      _skills[skill.name] = skill;
    }

    // 用户级 skills
    final home = _homePath;
    final userPath = '$home/.athena/skills';
    for (final skill in _loader.loadFromDirectory(userPath)) {
      _skills[skill.name] = skill;
    }
  }

  /// Level 1: 所有 Skill 的 name + description（注入 system prompt）
  String get level1Prompt {
    if (_skills.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('## Available Skills');
    buffer.writeln('You have access to the following skills. '
        'Use the "skill" tool to load one when it would help with the task.');
    buffer.writeln();
    for (final skill in _skills.values) {
      buffer.writeln('- **${skill.name}**: ${skill.description}');
    }
    return buffer.toString();
  }

  /// 获取单个 Skill 的 Level 2 完整内容
  String? getLevel2Content(String name) {
    return _skills[name]?.body;
  }

  /// 获取 Skill
  Skill? get(String name) => _skills[name];

  /// 所有已注册 Skill
  List<Skill> get all => _skills.values.toList();

  static String get _homePath {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
  }
}
```

- [ ] **Step 2: 验证**

```bash
flutter analyze lib/agent/skill/skill_registry.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/skill/skill_registry.dart
git commit -m "feat(agent): add SkillRegistry with progressive disclosure"
```

### Task 4.3: SkillTool（加载 Skill 的内置工具）

**Files:**
- Create: `lib/agent/tool/skill_tool.dart`

- [ ] **Step 1: 创建 SkillTool**

```dart
// lib/agent/tool/skill_tool.dart

import 'package:athena/agent/skill/skill_registry.dart';
import 'tool_interface.dart';

class SkillTool implements Tool {
  final SkillRegistry _registry;

  SkillTool(this._registry);

  @override
  String get name => 'skill';

  @override
  String get description => 'Load a skill by name to get specialized '
      'instructions for a specific task. Use when a skill would enhance '
      'your ability to complete the current task. '
      'Available skills are listed in the system prompt.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'The name of the skill to load.',
      },
    },
    'required': ['name'],
  };

  @override
  DangerLevel get dangerLevel => DangerLevel.safe;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final skill = _registry.get(name);
    if (skill == null) {
      return 'Error: Skill "$name" not found.';
    }
    final buffer = StringBuffer();
    buffer.writeln('Skill "$name" loaded successfully.');
    buffer.writeln();
    buffer.writeln('Instructions:');
    buffer.writeln(skill.body);
    return buffer.toString();
  }
}
```

- [ ] **Step 2: 验证**

```bash
flutter analyze lib/agent/tool/skill_tool.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/tool/skill_tool.dart
git commit -m "feat(agent): add SkillTool for loading skills"
```

### Task 4.4: 集成 Skill 系统到 AgentService

**Files:**
- Modify: `lib/agent/agent_service.dart`
- Modify: `lib/di.dart`

- [ ] **Step 1: AgentService 添加 skill prompt 处理**

修改 `agent_service.dart`，在所有 skill 的 level1 描述注入后，当 Agent 调用 `skill` 工具时，获取 level2 内容注入下一轮。关键逻辑已在 Task 2.1 的 `skillPrompt` 参数中预留。

在 `AgentService.run()` 方法中，skill prompt 的注入逻辑：

```dart
// 在工具执行后，检测是否调用了 'skill' 工具
// 如果是，获取该 skill 的完整 prompt 注入下一轮
for (final tc in toolCalls) {
  // ... execute tool ...
  if (tc.function.name == 'skill') {
    // Skill 的 execute() 返回内容已经包含了 skill body
    // 这些内容作为 tool result 注入 messages
    // LLM 在下一轮推理中自然会看到这些指令
  }
}
```

Skill 的 Level 2 加载是通过正常的工具调用流程完成的：Agent 调用 `skill(name="code-reviewer")` → SkillTool.execute() 返回 skill body → 作为 tool result 注入消息历史 → LLM 在下一轮看到这些指令并遵循。

- [ ] **Step 2: 更新 DI 注册**

在 `lib/di.dart` 中注册新组件：

```dart
// lib/di.dart

import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/skill/skill_loader.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/tool/file_read_tool.dart';
import 'package:athena/agent/tool/search_tool.dart';
import 'package:athena/agent/tool/shell_tool.dart';
import 'package:athena/agent/tool/skill_tool.dart';
import 'package:athena/agent/tool/tool_registry.dart';

class DI {
  static void ensureInitialized() {
    final getIt = GetIt.instance;

    // ... existing registrations ...

    // Agent
    getIt.registerLazySingleton(() {
      final registry = SkillRegistry();
      registry.loadAll();
      return registry;
    });

    getIt.registerLazySingleton(() {
      final skillRegistry = getIt<SkillRegistry>();
      final toolRegistry = ToolRegistry()
        ..registerAll([
          SearchTool(),
          FileReadTool(),
          ShellTool(),
          SkillTool(skillRegistry),
        ]);
      return toolRegistry;
    });

    getIt.registerLazySingleton(() => AgentService(
      toolRegistry: getIt<ToolRegistry>(),
    ));
  }
}
```

- [ ] **Step 3: 验证**

```bash
flutter analyze lib/agent/agent_service.dart lib/di.dart
```

Expected: No issues found.

- [ ] **Step 4: 提交**

```bash
git add lib/agent/agent_service.dart lib/di.dart
git commit -m "feat(agent): integrate skill system into agent loop and DI"
```

---

## Phase 5: 完善工具

### Task 5.1: FileWriteTool

**Files:**
- Create: `lib/agent/tool/file_write_tool.dart`

- [ ] **Step 1: 实现 FileWriteTool**

```dart
// lib/agent/tool/file_write_tool.dart

import 'dart:io';

import 'tool_interface.dart';

class FileWriteTool implements Tool {
  @override
  String get name => 'file_write';

  @override
  String get description => 'Write content to a file. Creates the file if it '
      'does not exist, overwrites it if it does. '
      'Use when you need to create or update a file.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'path': {
        'type': 'string',
        'description': 'The path to the file to write.',
      },
      'content': {
        'type': 'string',
        'description': 'The content to write to the file.',
      },
    },
    'required': ['path', 'content'],
  };

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final content = args['content'] as String;

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);

    return 'Successfully wrote ${content.length} bytes to $path';
  }
}
```

- [ ] **Step 2: 验证**

```bash
flutter analyze lib/agent/tool/file_write_tool.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/tool/file_write_tool.dart
git commit -m "feat(agent): add FileWriteTool"
```

### Task 5.2: FileDeleteTool

**Files:**
- Create: `lib/agent/tool/file_delete_tool.dart`

- [ ] **Step 1: 实现 FileDeleteTool**

```dart
// lib/agent/tool/file_delete_tool.dart

import 'dart:io';

import 'tool_interface.dart';

class FileDeleteTool implements Tool {
  @override
  String get name => 'file_delete';

  @override
  String get description => 'Delete a file. '
      'Use with caution — this operation cannot be undone.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'path': {
        'type': 'string',
        'description': 'The path to the file to delete.',
      },
    },
    'required': ['path'],
  };

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;

    final file = File(path);
    if (!await file.exists()) {
      return 'Error: File not found: $path';
    }

    await file.delete();
    return 'Successfully deleted $path';
  }
}
```

- [ ] **Step 2: 验证**

```bash
flutter analyze lib/agent/tool/file_delete_tool.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add lib/agent/tool/file_delete_tool.dart
git commit -m "feat(agent): add FileDeleteTool"
```

### Task 5.3: Shell 增强 + Search 增强

**Files:**
- Modify: `lib/agent/tool/shell_tool.dart`
- Modify: `lib/agent/tool/search_tool.dart`

- [ ] **Step 1: ShellTool 增加环境变量和工作目录参数**

在 ShellTool 的 parameters 中新增：

```dart
'workdir': {
  'type': 'string',
  'description': 'Working directory for the command. '
      'Defaults to the project root.',
},
```

在 execute 中使用该参数替代 `Directory.current.path`。

- [ ] **Step 2: SearchTool 增加更多文件类型支持**

在 grep 命令中增加 `--include` 参数覆盖更多文件类型：

```dart
'--include=*.{dart,yaml,md,json,js,ts,py,java,kt,swift,c,cpp,h,hpp,rs,go,rb,php,html,css,sql,xml,toml,cfg}',
```

- [ ] **Step 3: 验证**

```bash
flutter analyze lib/agent/tool/shell_tool.dart lib/agent/tool/search_tool.dart
```

Expected: No issues found.

- [ ] **Step 4: 提交**

```bash
git add lib/agent/tool/shell_tool.dart lib/agent/tool/search_tool.dart
git commit -m "feat(agent): enhance shell and search tools"
```

---

## Phase 6: 清理 MCP 相关代码

### Task 6.1: 移除 MCP 代码

**Files:**
- Delete: `lib/service/mcp_service.dart`
- Delete: `lib/view_model/server_view_model.dart`
- Delete: `lib/view_model/tool_view_model.dart`
- Delete: `lib/entity/server_entity.dart`
- Delete: `lib/entity/tool_entity.dart`
- Delete: `lib/page/desktop/home/component/server_selector.dart`
- Delete: `lib/repository/server_repository.dart`
- Delete: `lib/repository/tool_repository.dart`
- Delete: `lib/database/migration/migration_202501170002_add_server_fields.dart`
- Modify: `lib/di.dart`
- Modify: `lib/database/database.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: 移除 MCP 相关文件**

```bash
rm lib/service/mcp_service.dart
rm lib/view_model/server_view_model.dart
rm lib/view_model/tool_view_model.dart
rm lib/entity/server_entity.dart
rm lib/entity/tool_entity.dart
rm lib/page/desktop/home/component/server_selector.dart
rm lib/repository/server_repository.dart
rm lib/repository/tool_repository.dart
rm lib/database/migration/migration_202501170002_add_server_fields.dart
```

- [ ] **Step 2: 更新 pubspec.yaml**

移除 `dart_mcp` 依赖：

```yaml
# 删除这行:
# dart_mcp: ^0.2.2
```

- [ ] **Step 3: 更新 di.dart**

移除 MCP 相关注册：

```dart
// 删除以下 import 和注册:
// import 'package:athena/view_model/server_view_model.dart';
// import 'package:athena/view_model/tool_view_model.dart';
// getIt.registerLazySingleton(() => ToolViewModel());
// getIt.registerLazySingleton(() => ServerViewModel());
```

- [ ] **Step 4: 更新 database.dart**

移除 MCP 迁移 import 和调用：

```dart
// 删除:
// import 'package:athena/database/migration/migration_202501170002_add_server_fields.dart';
// await Migration202501170002AddServerFields().migrate();
```

- [ ] **Step 5: 清理引用**

运行分析找到所有残留引用并修复：

```bash
flutter analyze 2>&1 | grep "server_view_model\|tool_view_model\|mcp_service\|server_entity\|tool_entity\|server_selector\|server_repository\|tool_repository"
```

修复 home_page.dart 中移除 `serverViewModel` 引用等。

- [ ] **Step 6: 运行 pub get 和验证**

```bash
flutter pub get && flutter analyze
```

Expected: No issues found.

- [ ] **Step 7: 提交**

```bash
git add -A
git commit -m "chore: remove MCP-related code"
```

---

## 验证清单

全部阶段完成后运行：

```bash
flutter analyze     # 静态分析通过
flutter test        # 已有测试通过
flutter pub get     # 依赖正常
```
