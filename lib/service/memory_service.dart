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
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OpenAIClient(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
      headers: headers,
    );
    var prompt = PresetPrompt.memoryBatchAnalysisPrompt
        .replaceAll('{existing_memories}', existingMemories)
        .replaceAll('{chat_data}', chatData);
    var messages = [
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(prompt),
      ),
    ];
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.modelId),
      messages: messages,
    );
    var response = await client.createChatCompletion(request: request);
    return response.choices.first.message.content ?? '';
  }

  Future<String> synthesize({
    required String memoryData,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OpenAIClient(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
      headers: headers,
    );
    var prompt = PresetPrompt.memorySynthesisPrompt.replaceAll(
      '{memory_data}',
      memoryData,
    );
    var messages = [
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(prompt),
      ),
    ];
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.modelId),
      messages: messages,
    );
    var response = await client.createChatCompletion(request: request);
    return response.choices.first.message.content ?? '';
  }
}
