import 'dart:convert';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';

ProviderEntity messagesProvider() => ProviderEntity(
  id: '1',
  name: 'anthropic',
  baseUrl: 'https://api.anthropic.com/v1',
  apiKey: 'test-key',
  apiFormat: ApiFormat.messages,
  createdAt: DateTime(2026),
);

Map<String, dynamic> thinkingMessage({
  bool tools = true,
  String stop = 'tool_use',
  String suffix = '1',
}) => {
  'id': 'msg_$suffix',
  'type': 'message',
  'role': 'assistant',
  'model': 'claude-sonnet-4-6',
  'stop_reason': tools ? stop : 'end_turn',
  'stop_sequence': null,
  'usage': {
    'input_tokens': 100,
    'output_tokens': 80,
    'output_tokens_details': {'thinking_tokens': 25},
  },
  'content': [
    {
      'type': 'thinking',
      'thinking': '先读取配置。',
      'signature': 'signature_${suffix}_0',
    },
    {'type': 'text', 'text': '准备执行。'},
    {'type': 'redacted_thinking', 'data': 'redacted_$suffix'},
    {
      'type': 'thinking',
      'thinking': '',
      'signature': 'signature_${suffix}_hidden',
    },
    if (tools) _tool(0, suffix),
    {
      'type': 'thinking',
      'thinking': '再验证结果。',
      'signature': 'signature_${suffix}_1',
    },
    if (tools) _tool(1, suffix),
  ],
};

Map<String, dynamic> _tool(int index, String suffix) => {
  'type': 'tool_use',
  'id': 'toolu_${suffix}_$index',
  'name': 'echo',
  'input': {'value': '$index', 'call_description': 'Echo test value'},
};

List<Map<String, dynamic>> thinkingEvents(
  Map<String, dynamic> message, {
  bool initialText = false,
}) {
  final events = <Map<String, dynamic>>[
    {
      'type': 'message_start',
      'message': {
        ...message,
        'content': <Object>[],
        'stop_reason': null,
        'usage': {'input_tokens': 100, 'output_tokens': 0},
      },
    },
  ];
  final content = message['content'] as List;
  for (var i = 0; i < content.length; i++) {
    final block = Map<String, dynamic>.from(content[i] as Map);
    final type = block['type'];
    final key = type == 'thinking' ? 'thinking' : 'text';
    final text = block[key] as String? ?? '';
    events.add({
      'type': 'content_block_start',
      'index': i,
      'content_block': {
        ...block,
        if (type == 'thinking' || type == 'text')
          key: initialText && text.isNotEmpty ? text.substring(0, 1) : '',
        if (type == 'thinking') 'signature': '',
        if (type == 'tool_use') 'input': <String, dynamic>{},
      },
    });
    if (type == 'thinking' || type == 'text') {
      final rest = initialText && text.isNotEmpty ? text.substring(1) : text;
      events.add({
        'type': 'content_block_delta',
        'index': i,
        'delta': {'type': '${type}_delta', key: rest},
      });
      if (type == 'thinking') {
        events.add({
          'type': 'content_block_delta',
          'index': i,
          'delta': {'type': 'signature_delta', 'signature': block['signature']},
        });
      }
    } else if (type == 'tool_use') {
      // 验证流式参数中的空白不会让持久化指纹失配。
      final input = const JsonEncoder.withIndent('  ').convert(block['input']);
      final split = input.length ~/ 2;
      for (final part in [input.substring(0, split), input.substring(split)]) {
        events.add({
          'type': 'content_block_delta',
          'index': i,
          'delta': {'type': 'input_json_delta', 'partial_json': part},
        });
      }
    }
    events.add({'type': 'content_block_stop', 'index': i});
  }
  events.add({
    'type': 'message_delta',
    'delta': {'stop_reason': message['stop_reason']},
    'usage': {
      'output_tokens': 80,
      'output_tokens_details': {'thinking_tokens': 25},
    },
  });
  events.add({'type': 'message_stop'});
  return events;
}

String messagesSse(List<Map<String, dynamic>> events) => events
    .map((event) => 'event: ${event['type']}\ndata: ${jsonEncode(event)}\n\n')
    .join();
