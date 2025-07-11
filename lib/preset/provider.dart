class PresetProvider {
  static const providers = [
    {
      'is_preset': true,
      'key': '',
      'name': 'Deep Seek',
      'url': 'https://api.deepseek.com/v1',
      'models': [
        {
          'context': '64K context',
          'input_price': r'¥4/M input tokens',
          'name': 'DeepSeek-R1-0528',
          'output_price': r'¥16/M output tokens',
          'provider_id': 1,
          'released_at': 'Created 2025/05/28',
          'support_reasoning': true,
          'support_visual': false,
          'value': 'deepseek-reasoner'
        },
        {
          'context': '64K context',
          'input_price': r'¥2/M input tokens',
          'name': 'DeepSeek-V3-0324',
          'output_price': r'¥8/M output tokens',
          'provider_id': 1,
          'released_at': 'Created 2025/03/25',
          'support_reasoning': false,
          'support_visual': false,
          'value': 'deepseek-chat'
        }
      ]
    },
    {
      'is_preset': true,
      'key': '',
      'name': 'Open Router',
      'url': 'https://openrouter.ai/api/v1',
      'models': [
        {
          'context': '200,000 context',
          'input_price': r'$3/M input tokens',
          'name': 'Anthropic: Claude Sonnet 4',
          'output_price': r'$15/M output tokens',
          'provider_id': 2,
          'released_at': 'Created May 22, 2025',
          'support_reasoning': false,
          'support_visual': true,
          'value': 'anthropic/claude-sonnet-4'
        },
        {
          'context': '200,000 context',
          'input_price': r'$15/M input tokens',
          'name': 'Anthropic: Claude Opus 4',
          'output_price': r'$75/M output tokens',
          'provider_id': 2,
          'released_at': 'Created May 22, 2025',
          'support_reasoning': false,
          'support_visual': true,
          'value': 'anthropic/claude-opus-4'
        },
        {
          'context': '163,840 context',
          'input_price': r'$0.28/M input tokens',
          'name': 'DeepSeek: DeepSeek V3 0324',
          'output_price': r'$0.88/M output tokens',
          'provider_id': 2,
          'released_at': 'Created Mar 24, 2025',
          'support_reasoning': false,
          'support_visual': false,
          'value': 'deepseek/deepseek-chat-v3-0324'
        },
        {
          'context': '128,000 context',
          'input_price': r'$0.50/M input tokens',
          'name': 'DeepSeek: R1 0528',
          'output_price': r'$2.15/M output tokens',
          'provider_id': 2,
          'released_at': 'Created May 28, 2025',
          'support_reasoning': true,
          'support_visual': false,
          'value': 'deepseek/deepseek-r1-0528'
        },
        {
          'context': '1,048,576 context',
          'input_price': r'$0.30/M input tokens',
          'name': 'Google: Gemini 2.5 Flash',
          'output_price': r'$2.50/M output tokens',
          'provider_id': 2,
          'released_at': 'Created Jun 17, 2025',
          'support_reasoning': true,
          'support_visual': true,
          'value': 'google/gemini-2.5-flash'
        },
        {
          'context': '1,048,576 context',
          'input_price': r'Starting at $1.25/M input tokens',
          'name': 'Google: Gemini 2.5 Pro',
          'output_price': r'Starting at $10/M output tokens',
          'provider_id': 2,
          'released_at': 'Created Jun 17, 2025',
          'support_reasoning': true,
          'support_visual': true,
          'value': 'google/gemini-2.5-pro'
        },
        {
          'context': '1,048,576 context',
          'input_price': r'$0.15/M input tokens',
          'name': 'Meta: Llama 4 Maverick',
          'output_price': r'$0.60/M output tokens',
          'provider_id': 2,
          'released_at': 'Created Apr 5, 2025',
          'support_reasoning': true,
          'support_visual': true,
          'value': 'meta-llama/llama-4-maverick'
        },
        {
          'context': '1,047,576 context',
          'input_price': r'Starting at $2/M input tokens',
          'name': 'OpenAI: GPT-4.1',
          'output_price': r'Starting at $8/M output tokens',
          'provider_id': 2,
          'released_at': 'Created Apr 14, 2025',
          'support_reasoning': false,
          'support_visual': false,
          'value': 'openai/gpt-4.1'
        },
        {
          'context': '40,960 context',
          'input_price': r'$0.13/M input tokens',
          'name': 'Qwen: Qwen3 235B A22B',
          'output_price': r'$0.60/M output tokens',
          'provider_id': 2,
          'released_at': 'Created Apr 28, 2025',
          'support_reasoning': true,
          'support_visual': false,
          'value': 'qwen/qwen3-235b-a22b'
        },
        {
          'context': '256,000 context',
          'input_price': r'Starting at $3/M input tokens',
          'name': 'xAI: Grok 4',
          'output_price': r'Starting at $15/M output tokens',
          'provider_id': 2,
          'released_at': 'Created Jul 9, 2025',
          'support_reasoning': true,
          'support_visual': true,
          'value': 'x-ai/grok-4'
        }
      ]
    },
    {
      'is_preset': true,
      'key': '',
      'name': '阿里云百炼',
      'url': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'models': [
        {
          'context': '131,072 context',
          'input_price': r'¥0.004/K input tokens',
          'name': 'DeepSeek-R1',
          'output_price': r'¥0.016/K output tokens',
          'provider_id': 3,
          'released_at': 'Created 2025-05-28',
          'support_reasoning': true,
          'support_visual': false,
          'value': 'deepseek-r1'
        },
        {
          'context': '65,536 context',
          'input_price': r'¥0.002/K input tokens',
          'name': 'DeepSeek-V3',
          'output_price': r'¥0.008/K output tokens',
          'provider_id': 3,
          'released_at': 'Created 2024-12-26',
          'support_reasoning': false,
          'support_visual': false,
          'value': 'deepseek-v3'
        },
        {
          'context': '32,768 context',
          'input_price': r'¥0.0024/K input tokens',
          'name': '通义千问-Max',
          'output_price': r'¥0.0096/K output tokens',
          'provider_id': 3,
          'released_at': 'Created 2025-04-09',
          'support_reasoning': false,
          'support_visual': false,
          'value': 'qwen-max'
        },
        {
          'context': '131,072 context',
          'input_price': r'¥0.0008/K input tokens',
          'name': '通义千问-Plus',
          'output_price': r'¥0.002/K output tokens',
          'provider_id': 3,
          'released_at': 'Created 2025-06-24',
          'support_reasoning': false,
          'support_visual': false,
          'value': 'qwen-plus'
        },
        {
          'context': '1,000,000 context',
          'input_price': r'¥0.0003/K input tokens',
          'name': '通义千问-Turbo',
          'output_price': r'¥0.0006/K output tokens',
          'provider_id': 3,
          'released_at': 'Created 2025-06-24',
          'support_reasoning': false,
          'support_visual': false,
          'value': 'qwen-turbo'
        }
      ]
    },
    {
      'is_preset': true,
      'key': '',
      'name': '硅基流动',
      'url': 'https://api.siliconflow.cn/v1',
      'models': [
        {
          'context': '160K context',
          'input_price': r'￥4/ M input tokens',
          'name': 'DeepSeek-R1',
          'output_price': r'￥16/ M output tokens',
          'provider_id': 4,
          'released_at': 'Created 2025-05-28',
          'support_reasoning': true,
          'support_visual': false,
          'value': 'deepseek-ai/DeepSeek-R1'
        },
        {
          'context': '64K context',
          'input_price': r'￥2/ M input tokens',
          'name': 'DeepSeek-V3',
          'output_price': r'￥8/ M output tokens',
          'provider_id': 4,
          'released_at': 'Created 2025-03-24',
          'support_reasoning': false,
          'support_visual': false,
          'value': 'deepseek-ai/DeepSeek-V3'
        }
      ]
    },
    {
      'is_preset': true,
      'key': '',
      'name': '火山方舟',
      'url': 'https://ark.cn-beijing.volces.com/api/v3',
      'models': [
        {
          'context': '128K context',
          'input_price': r'¥4/M input tokens',
          'name': 'DeepSeek-R1',
          'output_price': r'¥16/M output tokens',
          'provider_id': 5,
          'released_at': 'Created 2025/05/28',
          'support_reasoning': true,
          'support_visual': false,
          'value': 'deepseek-r1-250528'
        },
        {
          'context': '128K context',
          'input_price': r'¥2/M input tokens',
          'name': 'DeepSeek-V3',
          'output_price': r'¥8/M output tokens',
          'provider_id': 5,
          'released_at': 'Created 2025/03/24',
          'support_reasoning': false,
          'support_visual': false,
          'value': 'deepseek-v3-250324'
        },
        {
          'context': '256K context',
          'input_price': r'Starting at ¥0.8/M input tokens',
          'name': 'Doubao-Seed-1.6-thinking',
          'output_price': r'Starting at ¥8/M output tokens',
          'provider_id': 5,
          'released_at': 'Created 2025/06/15',
          'support_reasoning': true,
          'support_visual': true,
          'value': 'doubao-seed-1-6-thinking-250615'
        },
        {
          'context': '256K context',
          'input_price': r'Starting at ¥0.15/M input tokens',
          'name': 'Doubao-Seed-1.6-flash',
          'output_price': r'Starting at ¥1.5/M input tokens',
          'provider_id': 5,
          'released_at': 'Created 2025/06/15',
          'support_reasoning': true,
          'support_visual': true,
          'value': 'doubao-seed-1-6-flash-250615'
        }
      ]
    }
  ];
}
