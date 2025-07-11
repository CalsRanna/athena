import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:athena/api/chat.dart';
import 'package:athena/api/search.dart';
import 'package:athena/model/search_decision.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/mcp.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/schema/tool.dart' hide Tool;
import 'package:athena/vendor/openai_dart/delta.dart';
import 'package:athena/vendor/openai_dart/response.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:dart_mcp/client.dart' hide Schema;
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
    var groupedMcpTools = await ref.read(mcpToolsNotifierProvider.future);
    List<Tool> tools = [];
    for (var tool in groupedMcpTools.values) {
      tools.addAll(tool);
    }
    var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
    if (!isDesktop) tools = [];
    var toolPrompt =
        PresetPrompt.toolPrompt.replaceAll('{tools}', jsonEncode(tools));
    var systemPrompt = '${sentinel.prompt}\n\n$toolPrompt';
    var systemMessage = ChatCompletionMessage.system(content: systemPrompt);
    var historyMessages = await _getHistoryMessages(latestChat);
    CallToolRequest? callToolRequest;
    try {
      var response = ChatApi().getCompletion(
        chat: latestChat,
        messages: [systemMessage, ...historyMessages],
        model: model,
        provider: provider,
      );
      var broadcast = response.asBroadcastStream();
      _streamingAssistantMessage(latestChat, broadcast);
      callToolRequest = await _getCallToolRequest(broadcast);
    } catch (error) {
      messagesNotifier.append(error.toString());
    }
    while (callToolRequest != null) {
      var result = await _getCallToolResult(latestChat, callToolRequest);
      var content = result != null ? result.content.toString() : '工具没有返回任何内容';
      var toolMessage = ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(content),
      );
      historyMessages.add(toolMessage);
      try {
        var nextRoundResponse = ChatApi().getCompletion(
          chat: latestChat,
          messages: [systemMessage, ...historyMessages],
          model: model,
          provider: provider,
        );
        var nextRoundBroadcast = nextRoundResponse.asBroadcastStream();
        _streamingAssistantMessage(latestChat, nextRoundBroadcast);
        callToolRequest = await _getCallToolRequest(nextRoundBroadcast);
      } catch (error) {
        messagesNotifier.append(error.toString());
      }
    }
    await messagesNotifier.closeStreaming(
      reference: formattedMessage.reference,
    );
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

  Future<void> terminateStreaming(Chat chat) async {
    var streamingNotifier = ref.read(streamingNotifierProvider.notifier);
    streamingNotifier.close();
    var messagesProvider = messagesNotifierProvider(chat.id);
    var messagesNotifier = ref.read(messagesProvider.notifier);
    await messagesNotifier.closeStreaming();
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

  Future<CallToolRequest?> _getCallToolRequest(
    Stream<OverrodeCreateChatCompletionStreamResponse> response,
  ) async {
    var buffer = StringBuffer();
    await for (final chunk in response) {
      if (chunk.response.choices.isEmpty) continue;
      var content = chunk.response.choices.first.delta.content ?? '';
      buffer.write(content);
    }
    var content = buffer.toString();
    var regex = RegExp(
      r'<CallToolRequest\s+name="(?<name>[^"]+)"\s+arguments="(?<arguments>\{.*\})"\s*><\/CallToolRequest>',
      caseSensitive: false,
      dotAll: true,
    );
    var matched = regex.firstMatch(content);
    if (matched == null) return null;
    var name = matched.namedGroup('name');
    var argumentsString = matched.namedGroup('arguments');
    if (name == null || argumentsString == null) return null;
    return CallToolRequest(name: name, arguments: jsonDecode(argumentsString));
  }

  Future<CallToolResult?> _getCallToolResult(
      Chat chat, CallToolRequest request) async {
    var messagesProvider = messagesNotifierProvider(chat.id);
    var messagesNotifier = ref.read(messagesProvider.notifier);
    var connection = await ref
        .read(mcpToolsNotifierProvider.notifier)
        .getConnectionByCallToolRequest(request);
    if (connection == null) {
      var content =
          '\n```${request.name}\nNo connection found for tool call\n```\n';
      var delta = OverrodeChatCompletionStreamResponseDelta(content: content);
      await messagesNotifier.streaming(delta);
      return null;
    }
    var result = await connection.callTool(request);
    var json = JsonEncoder.withIndent('  ').convert(result.content);
    var content = '\n```${request.name}\n$json\n```\n';
    var delta = OverrodeChatCompletionStreamResponseDelta(content: content);
    await messagesNotifier.streaming(delta);
    return result;
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
}
