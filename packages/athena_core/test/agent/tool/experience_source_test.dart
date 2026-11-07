import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/tool/experience_learn_tool.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/run_statistics.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late FileStorage storage;
  late ExperienceRepository experiences;
  late ExperienceRecallTool tool;
  late String chatId;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_experience_source_');
    storage = FileStorage(root: temp);
    experiences = ExperienceRepository(homeDir: temp.path);
    tool = ExperienceRecallTool(
      repository: experiences,
      messageRepository: storage.sessionRepository,
      chatRepository: storage.sessionRepository,
    );
    chatId = await storage.sessionRepository.createChat(
      ChatEntity(
        title: 'source',
        modelId: '1',
        sentinelId: '1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  });
  tearDown(() => temp.delete(recursive: true));

  Future<MessageEntity> message(String content, {String? runId = 'run-1'}) =>
      storage.sessionRepository.storeMessage(
        MessageEntity(
          chatId: chatId,
          role: 'assistant',
          content: content,
          reasoningContent: 'hidden reasoning',
          responsesState: 'encrypted state',
          runStatistics: runId == null
              ? null
              : RunStatistics(id: runId, startedAt: DateTime(2026)),
        ),
      );

  Future<String> read(
    String id, {
    String sentinelId = '1',
    bool includeArchived = false,
    String? workspacePath,
  }) => tool.execute({
    '_sentinel_id': sentinelId,
    'source_experience_id': id,
    'include_archived': includeArchived,
    '_experience_workspace': workspacePath,
  });

  test('只读来源及同轮此前的最近八条摘录，含压缩原文，不含隐藏推理和后续记录', () async {
    await message('unrelated earlier run', runId: 'other-run');
    for (var i = 0; i < 10; i++) {
      final row = await message('evidence-$i');
      await storage.sessionRepository.updateMessage(
        row.copyWith(compacted: true),
      );
    }
    final source = await message('start\n${'log' * 2000}\nvalidation passed');
    await message('future message');
    final experience = await experiences.save(
      lesson: 'verified lesson',
      sentinelId: '1',
      sourceChatId: chatId,
      sourceMessageId: source.id,
    );
    final result = await read(experience.id);
    final decoded = jsonDecode(result) as Map;
    final messages = decoded['messages'] as List;
    expect(messages, hasLength(8));
    expect(messages.first['content'], 'evidence-3');
    expect(messages.last['id'], source.id);
    expect(messages.last['content'], startsWith('start\n'));
    expect(messages.last['content'], endsWith('validation passed'));
    expect((messages.last['content'] as String).length, lessThan(2100));
    for (final excluded in [
      'unrelated earlier run',
      'future message',
      'hidden reasoning',
      'encrypted state',
    ]) {
      expect(result, isNot(contains(excluded)));
    }
  });

  test('旧消息缺少 run 标识时只返回来源本身', () async {
    await message('unrelated legacy', runId: null);
    final source = await message('legacy source', runId: null);
    final experience = await experiences.save(
      lesson: 'legacy',
      sentinelId: '1',
      sourceChatId: chatId,
      sourceMessageId: source.id,
    );
    final decoded = jsonDecode(await read(experience.id)) as Map;
    expect(decoded['messages'], hasLength(1));
    expect((decoded['messages'] as List).single['content'], 'legacy source');
  });

  test('项目经验及 shared 偏好的来源不会读出其他项目会话', () async {
    final a = p.join(temp.path, 'A');
    final b = p.join(temp.path, 'B');
    final chat = (await storage.sessionRepository.getChatById(chatId))!;
    await storage.sessionRepository.updateChat(chat.copyWith(workspacePath: a));
    final source = await message('project A details');
    final private = await experiences.save(
      lesson: 'project rule',
      sentinelId: '1',
      workspacePath: a,
      sourceChatId: chatId,
      sourceMessageId: source.id,
    );
    final shared = await experiences.save(
      lesson: 'shared preference',
      sentinelId: '1',
      scope: 'shared',
      sourceChatId: chatId,
      sourceMessageId: source.id,
    );
    expect(await read(private.id, workspacePath: b), contains('not found'));
    expect(
      await read(shared.id, workspacePath: b),
      contains('different project'),
    );
    expect(await read(shared.id), contains('different project'));
    expect(
      await read(private.id, workspacePath: a),
      contains('project A details'),
    );
    expect(
      await read(shared.id, workspacePath: a),
      contains('project A details'),
    );
  });

  test('私有经验及 shared 经验的原会话都不会跨角色读出', () async {
    final source = await message('private source details');
    final private = await experiences.save(
      lesson: 'private',
      sentinelId: '1',
      sourceChatId: chatId,
      sourceMessageId: source.id,
    );
    final shared = await experiences.save(
      lesson: 'shared',
      scope: 'shared',
      sentinelId: '1',
      sourceChatId: chatId,
      sourceMessageId: source.id,
    );
    expect(await read(private.id, sentinelId: '2'), contains('not found'));
    expect(
      await read(shared.id, sentinelId: '2'),
      contains('different Sentinel'),
    );
    expect(await read(shared.id), contains('private source details'));
  });

  test('无来源、已删除来源与归档经验明确返回结果', () async {
    final legacy = await experiences.save(lesson: 'legacy', sentinelId: '1');
    expect(await read(legacy.id), contains('No source recorded'));
    final source = await message('source');
    final experience = await experiences.save(
      lesson: 'archived',
      sentinelId: '1',
      sourceChatId: chatId,
      sourceMessageId: source.id,
    );
    await experiences.update(
      sentinelId: '1',
      id: experience.id,
      status: 'archived',
    );
    expect(await read(experience.id), contains('not found'));
    expect(
      await read(experience.id, includeArchived: true),
      contains(source.id!),
    );
    await storage.sessionRepository.deleteMessages(chatId, {source.id!});
    expect(
      await read(experience.id, includeArchived: true),
      contains('message is no longer available'),
    );
    await storage.sessionRepository.deleteChat(chatId);
    expect(
      await read(experience.id, includeArchived: true),
      contains('conversation is no longer available'),
    );
  });
}
