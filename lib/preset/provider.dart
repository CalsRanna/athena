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
          'name': 'Meta: Llama 3.3 70B Instruct',
          'value': 'meta-llama/llama-3.3-70b-instruct',
          'input_price': r'$0.12/M',
          'output_price': r'$0.30/M',
          'support_function_call': true,
          'max_token': 32768
        },
        {
          'name': 'Google: Gemini Flash 2.0 Experimental (free)',
          'value': 'google/gemini-2.0-flash-exp:free',
          'released_at': '2024-12-11',
          'input_price': r'$0.00/M',
          'output_price': r'$0.00/M',
          'support_function_call': true,
          'support_visual_recognition': true,
          'max_token': 1048576
        }
      ]
    },
    {
      'is_preset': true,
      'key': '',
      'name': 'Silicon Flow',
      'url': 'https://api.siliconflow.cn/v1',
      'models': [
        {
          'name': 'DeepSeek-R1',
          'value': 'deepseek-ai/DeepSeek-R1',
          'released_at': '2025-01-20',
          'input_price': r'$0.55/M',
          'output_price': r'$2.21/M',
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
        },
        {
          'name': 'Qwen2.5-72B-Instruct-128K',
          'value': 'Qwen/Qwen2.5-72B-Instruct-128K',
          'released_at': '2024-09-18',
          'support_function_call': true,
          'max_token': 131072
        },
        {
          'name': 'Llama-3.3-70B-Instruct',
          'value': 'meta-llama/Llama-3.3-70B-Instruct',
          'released_at': '2024-12-06',
          'support_function_call': true,
          'max_token': 32768
        },
        {
          'name': 'Qwen2.5-7B-Instruct (Free)',
          'value': 'Qwen/Qwen2.5-7B-Instruct',
          'released_at': '2024-09-18',
          'input_price': r'$0.00/M',
          'output_price': r'$0.00/M',
          'support_function_call': true,
          'max_token': 32768
        }
      ]
    }
  ];
}
