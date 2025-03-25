import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:athena/api/chat.dart';
import 'package:athena/api/search.dart';
import 'package:athena/model/search_decision.dart';
import 'package:athena/model/tool_call.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/mcp.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/provider/server.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/schema/tool.dart';
import 'package:athena/util/mcp_util.dart';
import 'package:athena/vendor/mcp/message.dart';
import 'package:athena/vendor/mcp/tool/tool.dart';
import 'package:athena/vendor/openai_dart/delta.dart';
import 'package:athena/vendor/openai_dart/response.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:isar/isar.dart';
import 'package:openai_dart/openai_dart.dart' hide Model;

class ChatViewModel extends ViewModel {
  final WidgetRef ref;
  ChatViewModel(this.ref);

  bool get streaming => ref.read(streamingNotifierProvider);

  Future<Chat> createChat({Sentinel? sentinel}) async {
    var model = await getFirstEnabledModel();
    var firstSentinel = await getFirstSentinel();
    var timestamp = DateTime.now();
    var chat = Chat()
      ..title = 'New Chat'
      ..modelId = model.id
      ..sentinelId = sentinel?.id ?? firstSentinel.id
      ..createdAt = timestamp
      ..updatedAt = timestamp;
    await isar.writeTxn(() async {
      chat.id = await isar.chats.put(chat);
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    return chat;
  }

  Future<void> destroyChat(Chat chat) async {
    await isar.writeTxn(() async {
      await isar.chats.delete(chat.id);
      await isar.messages.filter().chatIdEqualTo(chat.id).deleteAll();
    });
    var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
    if (isDesktop) {
      var count = await isar.chats.count();
      if (count == 0) {
        await createChat();
      }
    }
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
  }

  Future<void> destroyMessage(Message message) async {
    var builder = isar.messages.filter().chatIdEqualTo(message.chatId);
    final messages = await builder.findAll();
    final index = messages.indexWhere((item) => item.id == message.id);
    List<int> removed = [];
    for (var i = index; i < messages.length; i++) {
      removed.add(messages.elementAt(i).id);
    }
    await isar.writeTxn(() async {
      await isar.messages.deleteAll(removed);
    });
    ref.invalidate(messagesNotifierProvider(message.chatId));
  }

  Future<void> editMessage(Message message) async {
    await isar.writeTxn(() async {
      await isar.messages.put(message);
    });
    ref.invalidate(messagesNotifierProvider(message.chatId));
    var chat = await isar.chats.filter().idEqualTo(message.chatId).findFirst();
    if (chat == null) return;
    resendMessage(message, chat: chat);
  }

  Future<void> exportImage({
    required Chat chat,
    required GlobalKey repaintBoundaryKey,
  }) async {
    var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
    if (!isDesktop) {
      var bytes = await _generateImageBytes(repaintBoundaryKey, pixelRatio: 1);
      if (bytes == null) return;
      await ImageGallerySaverPlus.saveImage(bytes, quality: 100);
      AthenaDialog.message('Image exported successfully');
      return;
    }
    var exportPath = await FilePicker.platform.saveFile(
      fileName: '${chat.title}.png',
    );
    if (exportPath == null) return;
    var bytes = await _generateImageBytes(repaintBoundaryKey);
    if (bytes == null) return;
    await File(exportPath).writeAsBytes(bytes);
    AthenaDialog.message('Image exported to $exportPath');
  }

  Future<Chat> getFirstChat() async {
    var chats = await ref.read(chatsNotifierProvider.future);
    if (chats.isEmpty) return await createChat();
    return chats.first;
  }

  Future<Model> getFirstEnabledModel() async {
    var model = await ref.read(chatModelNotifierProvider.future);
    if (model.id != 0) return model;
    var result = await ref.read(groupedEnabledModelsNotifierProvider.future);
    if (result.isEmpty) return Model();
    var entry = result.entries.first;
    var models = entry.value;
    if (models.isEmpty) return Model();
    return models.first;
  }

  Future<Sentinel> getFirstSentinel() async {
    var sentinels = await ref.read(sentinelsNotifierProvider.future);
    if (sentinels.isEmpty) return Sentinel();
    return sentinels.first;
  }

  Future<Model> getModel(int id) async {
    var model = await isar.models.filter().idEqualTo(id).findFirst();
    return model ?? Model();
  }

  Future<Sentinel> getSentinel(int id) async {
    var sentinel = await isar.sentinels.filter().idEqualTo(id).findFirst();
    return sentinel ?? Sentinel();
  }

  Future<bool> hasModel() async {
    var models = await ref.read(groupedEnabledModelsNotifierProvider.future);
    return models.isNotEmpty;
  }

  Future<void> initChats() async {
    var count = await isar.chats.count();
    if (count > 0) return;
    await createChat();
  }

  void navigateSettingPage(BuildContext context) {
    DesktopSettingProviderRoute().push(context);
  }

  Future<Chat> renameChat(Chat chat) async {
    var messages = await ref.read(messagesNotifierProvider(chat.id).future);
    if (messages.isEmpty) return chat.copyWith(title: 'New Chat');
    var model = await ref.read(chatNamingModelNotifierProvider.future);
    var provider = providerNotifierProvider(model.providerId);
    var aiProvider = await ref.read(provider.future);
    var notifier = ref.read(chatsNotifierProvider.notifier);
    var title = '';
    try {
      final response = ChatApi().getTitle(
        messages.first.content,
        model: model,
        provider: aiProvider,
      );
      await for (final token in response) {
        title += token;
        title = title.replaceAll(' ', '').replaceAll('\n', '');
        notifier.updateChatTitle(title, chat: chat);
      }
    } catch (error) {
      title = error.toString().replaceAll(' ', '').replaceAll('\n', '');
      notifier.updateChatTitle(title, chat: chat);
    }
    var copiedChat = chat.copyWith(title: title);
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    return copiedChat;
  }

  Future<void> resendMessage(Message message, {required Chat chat}) async {
    var builder = isar.messages.filter().chatIdEqualTo(chat.id);
    final messages = await builder.findAll();
    final index = messages.indexWhere((item) => item.id == message.id);
    List<Message> removed = [];
    for (var i = index; i < messages.length; i++) {
      removed.add(messages.elementAt(i));
    }
    await isar.writeTxn(() async {
      await isar.messages.deleteAll(removed.map((item) => item.id).toList());
    });
    ref.invalidate(messagesNotifierProvider(chat.id));
    await sendMessage(message.content, chat: chat);
  }

  Future<void> sendMessage(String text, {required Chat chat}) async {
    final streamingNotifier = ref.read(streamingNotifierProvider.notifier);
    streamingNotifier.streaming();
    var chatProvider = chatNotifierProvider(chat.id);
    var latestChat = await ref.read(chatProvider.future);
    await _saveNewConversation(text, chat: latestChat);
    var decision = await _getSearchDecision(text, chat: latestChat);
    var formattedMessage = await _getFormattedMessage(text, decision: decision);
    var modelProvider = modelNotifierProvider(latestChat.modelId);
    var model = await ref.read(modelProvider.future);
    var providerProvider = providerNotifierProvider(model.providerId);
    var provider = await ref.read(providerProvider.future);
    var sentinelProvider = sentinelNotifierProvider(latestChat.sentinelId);
    var sentinel = await ref.read(sentinelProvider.future);
    var messagesProvider = messagesNotifierProvider(latestChat.id);
    var messagesNotifier = ref.read(messagesProvider.notifier);
    var servers = await ref.read(serversNotifierProvider.future);
    var completionTools = await _getChatCompletionTools();
    var systemMessage = ChatCompletionMessage.system(content: sentinel.prompt);
    var historyMessages = await _getHistoryMessages(latestChat);
    Map<int, ToolCall> toolCalls = {};
    try {
      var response = ChatApi().getCompletion(
        chat: latestChat,
        messages: [systemMessage, ...historyMessages],
        model: model,
        provider: provider,
        servers: servers,
        tools: completionTools.isNotEmpty ? completionTools : null,
      );
      var broadcast = response.asBroadcastStream();
      _streamingAssistantMessage(latestChat, broadcast);
      toolCalls = await _getToolCalls(broadcast);
    } catch (error) {
      messagesNotifier.append(error.toString());
    }
    while (toolCalls.isNotEmpty) {
      var entries = [...toolCalls.entries];
      toolCalls.clear();
      for (var entry in entries) {
        var toolCall = entry.value;
        await _streamingToolCallMessage(latestChat, toolCall);
        var result = await _streamingToolMessage(latestChat, toolCall);
        if (result == null) continue;
        var toolCallMessage = ChatCompletionMessage.assistant(
          toolCalls: [_getChatCompletionMessageToolCall(toolCall)],
        );
        var toolMessage = ChatCompletionMessage.tool(
          content: result.toString(),
          toolCallId: toolCall.id.toString(),
        );
        historyMessages.addAll([toolCallMessage, toolMessage]);
      }
      try {
        var responseWithToolCall = ChatApi().getCompletion(
          chat: latestChat,
          messages: [systemMessage, ...historyMessages],
          model: model,
          provider: provider,
          tools: completionTools.isNotEmpty ? completionTools : null,
          servers: servers,
        );
        var broadcastWithToolCall = responseWithToolCall.asBroadcastStream();
        _streamingAssistantMessage(latestChat, broadcastWithToolCall);
        toolCalls = await _getToolCalls(broadcastWithToolCall);
      } catch (error) {
        messagesNotifier.append(error.toString());
      }
    }
    await messagesNotifier.closeStreaming(
        reference: formattedMessage.reference);
    // Can not use the chat from params anymore cause the chat's title maybe
    // changed in the meantime
    var newChat =
        await isar.chats.filter().idEqualTo(latestChat.id).findFirst();
    var copiedChat = (newChat ?? Chat()).copyWith(updatedAt: DateTime.now());
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    streamingNotifier.close();
  }

  Future<void> updateContext(int context, {required Chat chat}) async {
    var copiedChat = chat.copyWith(context: context);
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatNotifierProvider(chat.id));
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
  }

  Future<Chat> updateEnableSearch(bool enabled, {required Chat chat}) async {
    var copiedChat = chat.copyWith(enableSearch: enabled);
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatNotifierProvider(chat.id));
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    return copiedChat;
  }

  Future<void> updateExpanded(Message message) async {
    var updatedMessage = message.copyWith(expanded: !message.expanded);
    await isar.writeTxn(() async {
      await isar.messages.put(updatedMessage);
    });
    ref.invalidate(messagesNotifierProvider(message.chatId));
  }

  Future<Chat> updateModel(Model model, {required Chat chat}) async {
    var copiedChat = chat.copyWith(modelId: model.id);
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatNotifierProvider(chat.id));
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    return copiedChat;
  }

  Future<Chat> updateSentinel(Sentinel sentinel, {required Chat chat}) async {
    var copiedChat = chat.copyWith(sentinelId: sentinel.id);
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatNotifierProvider(chat.id));
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    return copiedChat;
  }

  Future<void> updateTemperature(double temperature,
      {required Chat chat}) async {
    var copiedChat = chat.copyWith(temperature: temperature);
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatNotifierProvider(chat.id));
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
  }

  Future<Uint8List?> _generateImageBytes(
    GlobalKey repaintBoundaryKey, {
    double pixelRatio = 4.0,
  }) async {
    var boundary = repaintBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    var image = await boundary.toImage(pixelRatio: pixelRatio);
    var byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  }

  ChatCompletionMessageToolCall _getChatCompletionMessageToolCall(
    ToolCall toolCall,
  ) {
    var chatCompletionMessageFunctionCall = ChatCompletionMessageFunctionCall(
      name: toolCall.name.toString(),
      arguments: toolCall.arguments.toString(),
    );
    return ChatCompletionMessageToolCall(
      id: toolCall.id.toString(),
      type: ChatCompletionMessageToolCallType.function,
      function: chatCompletionMessageFunctionCall,
    );
  }

  Future<List<ChatCompletionTool>> _getChatCompletionTools() async {
    List<ChatCompletionTool> completionTools = [];
    var mcpTools = await ref.read(mcpToolsNotifierProvider.future);
    for (var mcpTool in mcpTools) {
      var function = FunctionObject(
        name: mcpTool.name,
        description: mcpTool.description,
        parameters: mcpTool.inputSchema.toJson(),
      );
      var completionTool = ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: function,
      );
      completionTools.add(completionTool);
    }
    var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
    if (!isDesktop) return [];
    return completionTools;
  }

  Future<Message> _getFormattedMessage(
    String text, {
    required SearchDecision decision,
  }) async {
    var message = Message()..content = text;
    if (decision.needSearch) {
      var tool = await isar.tools.filter().nameEqualTo('Tavily').findFirst();
      if (tool == null) return message;
      if (tool.key.isEmpty) return message;
      var searchResult = await SearchApi().search(decision.query, tool: tool);
      var reference = jsonEncode(searchResult);
      message.content = PresetPrompt.formatMessagePrompt
          .replaceAll('{input}', text)
          .replaceAll('{reference}', reference);
      message.reference = reference;
    }
    return message;
  }

  Future<List<ChatCompletionMessage>> _getHistoryMessages(Chat chat) async {
    var messagesProvider = messagesNotifierProvider(chat.id);
    var messages = await ref.read(messagesProvider.future);
    var context = messages.length;
    if (chat.context > 0) {
      context = min(chat.context * 2, messages.length);
    }
    var start = max(0, messages.length - context);
    var histories = messages.sublist(start).where((message) {
      return message.content.isNotEmpty;
    });
    return histories.map((message) {
      if (message.role == 'assistant') {
        return ChatCompletionMessage.assistant(content: message.content);
      } else {
        return ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(message.content),
        );
      }
    }).toList();
  }

  Future<McpTool> _getMcpTool(ToolCall toolCall) async {
    var mcpTools = await ref.read(mcpToolsNotifierProvider.future);
    return mcpTools
        .where((mcpTool) => mcpTool.name == toolCall.name.toString())
        .first;
  }

  Map<String, dynamic> _getMcpToolArguments(ToolCall toolCall) {
    Map<String, dynamic> arguments;
    try {
      arguments = jsonDecode(toolCall.arguments.toString());
    } catch (e) {
      arguments = {};
    }
    return arguments;
  }

  Future<SearchDecision> _getSearchDecision(
    String text, {
    required Chat chat,
  }) async {
    var latestChat = await ref.read(chatNotifierProvider(chat.id).future);
    if (!latestChat.enableSearch) return SearchDecision();
    var searchDecisionModel = chatSearchDecisionModelNotifierProvider;
    var model = await ref.read(searchDecisionModel.future);
    var searchDecisionProvider = providerNotifierProvider(model.providerId);
    var provider = await ref.read(searchDecisionProvider.future);
    var messagesProvider = messagesNotifierProvider(latestChat.id);
    var messages = await ref.read(messagesProvider.future);
    var userMessages = messages.where((message) => message.role == 'user');
    if (userMessages.isEmpty) return SearchDecision();
    var historyText = userMessages.map((message) => message.content).join('\n');
    var fullText = '$historyText\n$text';
    return await ChatApi().getSearchDecision(
      fullText,
      provider: provider,
      model: model,
    );
  }

  Future<Map<int, ToolCall>> _getToolCalls(
    Stream<OverrodeCreateChatCompletionStreamResponse> response,
  ) async {
    Map<int, ToolCall> toolCalls = {};
    await for (final chunk in response) {
      if (chunk.response.choices.isEmpty) continue;
      if (chunk.response.choices.first.delta.toolCalls != null) {
        if (chunk.response.choices.first.delta.toolCalls!.isEmpty) continue;
        var toolCallChunk = chunk.response.choices.first.delta.toolCalls!.first;
        if (!toolCalls.containsKey(toolCallChunk.index)) {
          toolCalls[toolCallChunk.index] = ToolCall();
        }
        toolCalls[toolCallChunk.index]!.process(toolCallChunk);
        continue;
      }
    }
    return toolCalls;
  }

  Future<void> _saveNewConversation(String text, {required Chat chat}) async {
    final userMessage = Message();
    userMessage.chatId = chat.id;
    userMessage.content = text;
    userMessage.role = 'user';
    final assistantMessage = Message();
    assistantMessage.chatId = chat.id;
    assistantMessage.role = 'assistant';
    await isar.writeTxn(() async {
      await isar.messages.putAll([userMessage, assistantMessage]);
    });
    ref.invalidate(messagesNotifierProvider(chat.id));
  }

  Future<void> _streamingAssistantMessage(
    Chat chat,
    Stream<OverrodeCreateChatCompletionStreamResponse> response,
  ) async {
    var messagesProvider = messagesNotifierProvider(chat.id);
    var messagesNotifier = ref.read(messagesProvider.notifier);
    await for (final chunk in response) {
      if (chunk.response.choices.isEmpty) continue;
      var content = chunk.response.choices.first.delta.content ?? '';
      var rawDelta = chunk.rawJson['choices'][0]['delta'];
      var reasoningContent = rawDelta['reasoning_content']; // DeepSeek
      reasoningContent ??= rawDelta['reasoning']; // OpenRouter
      var delta = OverrodeChatCompletionStreamResponseDelta(
        content: content,
        reasoningContent: reasoningContent,
      );
      await messagesNotifier.streaming(delta);
    }
  }

  Future<void> _streamingToolCallMessage(Chat chat, ToolCall toolCall) async {
    var messagesProvider = messagesNotifierProvider(chat.id);
    var messagesNotifier = ref.read(messagesProvider.notifier);
    var content = '\n\nCalling ${toolCall.name}\n';
    var delta = OverrodeChatCompletionStreamResponseDelta(content: content);
    await messagesNotifier.streaming(delta);
    var json = JsonEncoder.withIndent('  ').convert(toolCall);
    content = '\n```${toolCall.id}\n$json\n```\n';
    delta = OverrodeChatCompletionStreamResponseDelta(content: content);
    await messagesNotifier.streaming(delta);
  }

  Future<McpJsonRpcResponse?> _streamingToolMessage(
    Chat chat,
    ToolCall toolCall,
  ) async {
    var messagesProvider = messagesNotifierProvider(chat.id);
    var messagesNotifier = ref.read(messagesProvider.notifier);
    var content = '\n\nGet result from ${toolCall.name}\n';
    var delta = OverrodeChatCompletionStreamResponseDelta(content: content);
    await messagesNotifier.streaming(delta);
    var serversProvider = serversNotifierProvider;
    var servers = await ref.read(serversProvider.future);
    var server = await McpUtil.getServer(toolCall, servers: servers);
    McpJsonRpcResponse? result;
    if (server == null) {
      content = '\n```tool_call_error\nNo server found for tool call\n```\n';
      delta = OverrodeChatCompletionStreamResponseDelta(content: content);
    } else {
      var tool = await _getMcpTool(toolCall);
      var arguments = _getMcpToolArguments(toolCall);
      result = await McpUtil.callTool(tool, server, arguments: arguments);
      var json = JsonEncoder.withIndent('  ').convert(result);
      content = '\n```${result.id}\n$json\n```\n';
      delta = OverrodeChatCompletionStreamResponseDelta(content: content);
    }
    await messagesNotifier.streaming(delta);
    return result;
  }
}
