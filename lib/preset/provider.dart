class PresetProvider {
  static const providers = [
    {
      'is_preset': true,
      'key': '',
      'name': 'Deep Seek',
      'url': 'https://api.deepseek.com/v1',
      'models': [
        {
          'name': 'DeepSeek-R1',
          'value': 'deepseek-reasoner',
          'released_at': '2025-01-20',
          'input_price': r'$0.55/M',
          'output_price': r'$2.21/M',
          'support_thinking': true,
          'max_token': 65536
        },
        {
          'name': 'DeepSeek-V3',
          'value': 'deepseek-chat',
          'released_at': '2024-12-26',
          'input_price': r'$0.28/M',
          'output_price': r'$1.10/M',
          'support_function_call': true,
          'max_token': 65536
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
          'name': 'Anthropic: Claude 3.5 Sonnet',
          'value': 'anthropic/claude-3.5-sonnet',
          'released_at': '2024-06-20',
          'input_price': r'$3.00/M',
          'output_price': r'$15.00/M',
          'support_function_call': true,
          'support_visual_recognition': true,
          'max_token': 200000
        },
        {
          'name': 'Anthropic: Claude 3.7 Sonnet',
          'value': 'anthropic/claude-3.7-sonnet',
          'released_at': '2025-02-24',
          'input_price': r'$3.00/M',
          'output_price': r'$15.00/M',
          'support_function_call': true,
          'support_visual_recognition': true,
          'max_token': 200000
        },
        {
          'name': 'DeepSeek: DeepSeek V3',
          'value': 'deepseek/deepseek-chat',
          'released_at': '2024-12-26',
          'input_price': r'$0.4/M',
          'output_price': r'$1.3/M',
          'support_function_call': true,
          'max_token': 64000
        },
        {
          'name': 'DeepSeek: R1',
          'value': 'deepseek/deepseek-r1',
          'released_at': '2025-01-20',
          'input_price': r'$0.55/M',
          'output_price': r'$2.19/M',
          'support_function_call': true,
          'support_thinking': true,
          'max_token': 65536
        },
        {
          'name': 'Google: Gemini Flash 2.0',
          'value': 'google/gemini-2.0-flash-001',
          'released_at': '2025-02-05',
          'input_price': r'$0.10/M',
          'output_price': r'$0.40/M',
          'support_function_call': true,
          'support_visual_recognition': true,
          'max_token': 1056768
        },
        {
          'name': 'Meta: Llama 3.3 70B Instruct',
          'value': 'meta-llama/llama-3.3-70b-instruct',
          'input_price': r'$0.12/M',
          'output_price': r'$0.30/M',
          'support_function_call': true,
          'max_token': 32768
        },
        {
          'name': 'OpenAI: GPT-4o (2024-11-20)',
          'value': 'openai/gpt-4o-2024-11-20',
          'released_at': '2024-11-20',
          'input_price': r'$2.50/M',
          'output_price': r'$10.00/M',
          'support_function_call': true,
          'support_visual_recognition': true,
          'max_token': 128000
        },
        {
          'name': 'Qwen: QwQ 32B',
          'value': 'qwen/qwq-32b',
          'released_at': '2025-03-05',
          'input_price': r'$0.12/M',
          'output_price': r'$0.18/M',
          'support_function_call': true,
          'max_token': 131072
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
          'name': 'DeepSeek-R1',
          'value': 'deepseek-r1',
          'released_at': '2025-01-27',
          'input_price': r'¥0.004/K',
          'output_price': r'¥0.016/K',
          'support_thinking': true,
          'max_token': 65536
        },
        {
          'name': 'DeepSeek-V3',
          'value': 'deepseek-v3',
          'released_at': '2025-01-27',
          'input_price': r'¥0.002/K',
          'output_price': r'¥0.008/K',
          'max_token': 65536
        },
        {
          'name': '通义千问-Omni-Turbo',
          'value': 'qwen-omni-turbo',
          'released_at': '2025-02-14',
          'input_price': r'$0.0004/K',
          'output_price': r'$0.0016/K',
          'support_function_call': true,
          'support_visual_recognition': true,
          'max_token': 32768
        },
        {
          'name': '通义千问-QwQ-Plus',
          'value': 'qwq-plus',
          'released_at': '2025-03-05',
          'input_price': r'¥0.0016/K',
          'output_price': r'¥0.004/K',
          'support_function_call': true,
          'support_thinking': true,
          'max_token': 131072
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
          'name': 'DeepSeek-R1',
          'value': 'deepseek-ai/DeepSeek-R1',
          'released_at': '2025-01-20',
          'input_price': r'$0.55/M',
          'output_price': r'$2.21/M',
          'support_function_call': true,
          'support_thinking': true,
          'max_token': 65536
        },
        {
          'name': 'DeepSeek-V3',
          'value': 'deepseek-ai/DeepSeek-V3',
          'released_at': '2024-12-26',
          'input_price': r'$0.28/M',
          'output_price': r'$1.10/M',
          'support_function_call': true,
          'max_token': 65536
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
          'name': 'DeepSeek-R1',
          'value': 'deepseek-r1-250120',
          'released_at': '2025-03-13',
          'input_price': r'¥0.004/K',
          'output_price': r'¥0.016/K',
          'support_function_call': true,
          'support_thinking': true,
          'max_token': 65536
        },
        {
          'name': 'DeepSeek-V3',
          'value': 'deepseek-v3-241226',
          'released_at': '2025-03-13',
          'input_price': r'¥0.004/K',
          'output_price': r'¥0.016/K',
          'support_function_call': true,
          'max_token': 65536
        },
        {
          'name': 'Doubao-1.5-pro-32k',
          'value': 'doubao-1-5-pro-32k-250115',
          'released_at': '2025-03-05',
          'input_price': r'¥0.0008/K',
          'output_price': r'¥0.002/K',
          'support_function_call': true,
          'max_token': 32768
        }
      ]
    }
  ];
}
