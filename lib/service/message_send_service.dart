import 'dart:async';
import 'dart:convert';

import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:openai_dart/openai_dart.dart';

sealed class SendEvent {}

class SendTextDelta extends SendEvent {
  final String delta;
  SendTextDelta(this.delta);
}

class SendReasoningDelta extends SendEvent {
  final String delta;
  SendReasoningDelta(this.delta);
}

class SendToolCall extends SendEvent {
  final String id;
  final String name;
  final String arguments;
  SendToolCall({required this.id, required this.name, required this.arguments});
}

class SendToolResult extends SendEvent {
  final String id;
  final String name;
  final String result;
  SendToolResult({required this.id, required this.name, required this.result});
}

class SendIterationEnd extends SendEvent {}

class SendDone extends SendEvent {
  final String content;
  SendDone(this.content);
}

class MessageSendService {
  final AgentService _agentService;

  MessageSendService({required AgentService agentService})
      : _agentService = agentService;

  Stream<SendEvent> sendMessage({
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> baseMessages,
    required int maxIterations,
    required ModelEntity? auxiliaryModel,
    required ProviderEntity? auxiliaryModelProvider,
    required PermissionService permissionService,
    required Future<bool> Function(String toolName, String arguments) onPermission,
  }) async* {
    final agentStream = _agentService.run(
      chat: chat,
      provider: provider,
      model: model,
      baseMessages: baseMessages,
      maxIterations: maxIterations,
      auxiliaryModel: auxiliaryModel,
      auxiliaryModelProvider: auxiliaryModelProvider,
      permissionService: permissionService,
      onPermission: onPermission,
    );

    await for (final event in agentStream) {
      if (event is AgentReasoningEvent) {
        yield SendReasoningDelta(event.delta);
      } else if (event is AgentTextEvent) {
        yield SendTextDelta(event.delta);
      } else if (event is AgentToolCallEvent) {
        yield SendToolCall(
          id: event.id,
          name: event.name,
          arguments: event.arguments,
        );
      } else if (event is AgentToolResultEvent) {
        yield SendToolResult(
          id: event.id,
          name: event.name,
          result: event.result,
        );
      } else if (event is AgentDoneEvent) {
        yield SendDone(event.content);
      }
    }
  }

  String formatToolArgs(String toolName, String arguments) {
    final buffer = StringBuffer();
    buffer.writeln('Agent wants to use: $toolName');
    try {
      final args = jsonDecode(arguments) as Map<String, dynamic>;
      for (final entry in args.entries) {
        var value = entry.value.toString();
        if (value.length > 120) {
          value = '${value.substring(0, 120)}...';
        }
        buffer.writeln('  ${entry.key}: $value');
      }
    } catch (_) {
      if (arguments.length > 200) {
        buffer.writeln('  ${arguments.substring(0, 200)}...');
      } else {
        buffer.writeln('  $arguments');
      }
    }
    return buffer.toString();
  }
}
