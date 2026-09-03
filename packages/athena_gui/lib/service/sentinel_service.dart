import 'dart:convert';

import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';

/// 仅生成 Sentinel 名称的 prompt
const _nameGenerationPrompt = '''
你是一个专业的AI助手名称生成器。根据用户提供的 agent prompt，生成一个简洁的名称。
只返回 JSON 格式：{"name": "..."}

示例：
用户输入: "一位专精于中国古典文学的学者，精通诗词歌赋"
输出: {"name": "诗词大家"}
''';

/// 仅生成 Sentinel 描述的 prompt
const _descriptionGenerationPrompt = '''
你是一个专业的AI助手描述生成器。根据用户提供的 agent prompt 和已有名称，生成简短的描述。
只返回 JSON 格式：{"description": "..."}

示例：
用户输入: "一位专精于中国古典文学的学者，精通诗词歌赋"
已有名称: "诗词大家"
输出: {"description": "专精中国古典文学的虚拟学者，精通诗词歌赋，提供各朝代文学作品的赏析与解读。"}
''';

const _metadataGenerationPrompt = '''
R - Role (角色):
你是一位专业的AI助手元数据生成器,擅长分析用户输入的agent prompt,并生成相应的名称、描述、
标签和表情符号头像。

O - Objectives (目标):
1. 分析用户提供的agent prompt
2. 生成符合prompt内容的name(名称)
3. 创建简洁的description(描述)
4. 提供相关的tags(标签)
5. 选择一个合适的emoji作为avatar(头像)
6. 将所有生成的信息组织成JSON格式输出

S - Style (风格):
保持输出简洁明了,description不要过长。name、description和tags可以使用中文。

C - Content (内容/上下文):
你需要理解各种可能的agent prompt,包括但不限于不同领域的专业知识、特定任务、角色扮演等。无论
用户输入什么,都要基于输入内容生成所需的元数据,而不是将用户输入作为message直接使用。

I - Input (输入):
用户将提供一个agent prompt,可能是几个词到几个句子不等。

R - Response (响应):
返回一个JSON对象,包含以下字段:
- name: 字符串,agent的名称
- description: 字符串,简短的描述
- tags: 字符串数组,相关标签
- avatar: 字符串,一个emoji表情

A - Audience (受众):
使用该系统的开发者或用户,他们需要为自定义的agent快速生成元数据。

W - Workflow (工作流):
1. 仔细阅读并分析用户提供的agent prompt
2. 提取prompt中的关键信息和主题
3. 基于分析结果生成简洁的name
4. 创建简短的description,概括agent的主要功能或特点
5. 选择3-5个相关的tags
6. 选择一个最能代表agent特征的emoji作为avatar
7. 将所有生成的信息组织成指定的JSON格式
8. 检查确保所有字段都已填写,且内容与原始prompt相符
9. 返回生成的JSON对象

示例:
用户输入: "一位专精于中国古典文学的学者,精通诗词歌赋,能够赏析解读各朝代的文学作品。"

输出:
{
  "name": "诗词大家",
  "description": "专精中国古典文学的虚拟学者,精通诗词歌赋,提供各朝代文学作品的赏析与解读。",
  "tags": ["中国文学", "古典诗词", "文学赏析", "学者"],
  "avatar": "📜"
}
''';

/// SentinelService 负责 Sentinel 生成相关的网络请求
class SentinelService {
  final LlmClient _llmClient;

  SentinelService({required LlmClient llmClient}) : _llmClient = llmClient;

  /// 仅生成 Sentinel 名称
  Future<String> generateName(
    String prompt, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    final sentinel = await _generateWithPrompt(
      prompt: prompt,
      systemPrompt: _nameGenerationPrompt,
      provider: provider,
      model: model,
    );
    return sentinel.name;
  }

  /// 仅生成 Sentinel 描述，可传入已有名称作为上下文
  Future<String> generateDescription(
    String prompt, {
    required ProviderEntity provider,
    required ModelEntity model,
    String existingName = '',
  }) async {
    final userContent = existingName.isNotEmpty
        ? '已有名称: $existingName\n$prompt'
        : prompt;
    final sentinel = await _generateWithPrompt(
      prompt: userContent,
      systemPrompt: _descriptionGenerationPrompt,
      provider: provider,
      model: model,
    );
    return sentinel.description;
  }

  /// 内部通用方法：使用指定的 system prompt 调用 LLM 生成
  Future<SentinelEntity> _generateWithPrompt({
    required String prompt,
    required String systemPrompt,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var messages = [
      ChatMessage.system(systemPrompt),
      ChatMessage.user(prompt),
    ];
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
      responseFormat: ResponseFormat.jsonObject(),
    );
    var response = await _llmClient.fetch(
      provider: provider,
      request: request,
    );
    final content = response.text ?? '';
    final decoded = jsonDecode(content);
    final formatted =
        decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    final tags = formatted['tags'] is List
        ? (formatted['tags'] as List).map((e) => e.toString()).join(',')
        : (formatted['tags']?.toString() ?? '');
    return SentinelEntity(
      name: formatted['name']?.toString() ?? '',
      description: formatted['description']?.toString() ?? '',
      tags: tags,
      avatar: formatted['avatar']?.toString() ?? '',
      prompt: prompt,
    );
  }

  /// 基于用户输入的 prompt 生成完整 Sentinel 元数据（名称、描述、标签、头像）
  Future<SentinelEntity> generate(
    String prompt, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    return _generateWithPrompt(
      prompt: prompt,
      systemPrompt: _metadataGenerationPrompt,
      provider: provider,
      model: model,
    );
  }
}
