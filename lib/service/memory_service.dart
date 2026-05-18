import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/preset/prompt.dart';
import 'package:openai_dart/openai_dart.dart';

class MemoryService {
  Future<String> analyzeBatch({
    required String existingMemories,
    required String chatData,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var client = OpenAIClient.withApiKey(
      provider.apiKey,
      baseUrl: provider.baseUrl,
      defaultHeaders: {
        'HTTP-Referer': 'https://github.com/CalsRanna/athena',
        'X-Title': 'Athena',
      },
    );
    var prompt = PresetPrompt.memoryBatchAnalysisPrompt
        .replaceAll('{existing_memories}', existingMemories)
        .replaceAll('{chat_data}', chatData);
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: [ChatMessage.user(prompt)],
    );
    var response = await client.chat.completions.create(request);
    return response.text ?? '';
  }

  Future<String> synthesize({
    required String memoryData,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var client = OpenAIClient.withApiKey(
      provider.apiKey,
      baseUrl: provider.baseUrl,
      defaultHeaders: {
        'HTTP-Referer': 'https://github.com/CalsRanna/athena',
        'X-Title': 'Athena',
      },
    );
    var prompt = PresetPrompt.memorySynthesisPrompt.replaceAll(
      '{memory_data}',
      memoryData,
    );
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: [ChatMessage.user(prompt)],
    );
    var response = await client.chat.completions.create(request);
    return response.text ?? '';
  }
}
