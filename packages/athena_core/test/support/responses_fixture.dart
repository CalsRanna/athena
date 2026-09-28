import 'dart:convert';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';

ProviderEntity responsesProvider() => ProviderEntity(
  id: '1',
  name: 'test',
  baseUrl: 'https://example.test/v1',
  apiKey: 'test-secret',
  apiFormat: ApiFormat.responses,
  createdAt: DateTime(2026),
);

Map<String, dynamic> reasoningResponse({
  bool tools = true,
  String status = 'completed',
  String suffix = '1',
}) => {
  'id': 'resp_$suffix',
  'object': 'response',
  'created_at': 1,
  'status': status,
  'model': 'test-reasoner',
  'output': [
    {
      'type': 'reasoning',
      'id': 'rs_$suffix',
      'summary': [
        {'type': 'summary_text', 'text': '先读取配置。'},
        {'type': 'summary_text', 'text': '再验证结果。'},
      ],
      'encrypted_content': 'opaque-cipher-$suffix',
    },
    {
      'type': 'message',
      'id': 'msg_$suffix',
      'role': 'assistant',
      'phase': tools ? 'commentary' : 'final_answer',
      'status': 'completed',
      'content': [
        {
          'type': 'output_text',
          'text': tools ? '准备执行。' : '完成。',
          'annotations': <Object>[],
        },
      ],
    },
    if (tools)
      for (var i = 0; i < 2; i++)
        {
          'type': 'function_call',
          'id': 'fc_${suffix}_$i',
          'call_id': 'call_${suffix}_$i',
          'name': 'echo',
          'arguments': jsonEncode({'value': '$i', 'call_description': '测试读取'}),
          'status': 'completed',
        },
  ],
  'usage': {
    'input_tokens': 20,
    'output_tokens': 30,
    'total_tokens': 50,
    'input_tokens_details': {'cached_tokens': 10},
    'output_tokens_details': {'reasoning_tokens': 25},
  },
  if (status == 'incomplete')
    'incomplete_details': {'reason': 'max_output_tokens'},
};

List<Map<String, dynamic>> reasoningEvents(Map<String, dynamic> response) {
  final output = response['output'] as List;
  return [
    {
      'type': 'response.reasoning_summary_text.delta',
      'output_index': 0,
      'summary_index': 0,
      'delta': '先读取',
    },
    {
      'type': 'response.reasoning_summary_text.delta',
      'output_index': 0,
      'summary_index': 0,
      'delta': '配置。',
    },
    {
      'type': 'response.reasoning_summary_text.done',
      'output_index': 0,
      'summary_index': 0,
      'text': '先读取配置。',
    },
    {
      'type': 'response.reasoning_summary_text.done',
      'output_index': 0,
      'summary_index': 1,
      'text': '再验证结果。',
    },
    {'type': 'response.output_item.done', 'output_index': 0, 'item': output[0]},
    {
      'type': 'response.output_text.delta',
      'output_index': 1,
      'content_index': 0,
      'delta': output[1]['content'][0]['text'],
    },
    for (var i = 2; i < output.length; i++) ...[
      {
        'type': 'response.output_item.added',
        'output_index': i,
        'item': {...output[i] as Map<String, dynamic>, 'arguments': ''},
      },
      {
        'type': 'response.function_call_arguments.delta',
        'output_index': i,
        'delta': output[i]['arguments'],
      },
    ],
    {
      'type': response['status'] == 'incomplete'
          ? 'response.incomplete'
          : 'response.completed',
      'response': response,
    },
  ];
}

String responsesSse(List<Map<String, dynamic>> events) => events
    .map((event) => 'event: ${event['type']}\ndata: ${jsonEncode(event)}\n\n')
    .join();
