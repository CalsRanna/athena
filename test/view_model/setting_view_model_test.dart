import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

// 这些测试针对审计 C6：importData 从其他实例导入数据后，本地 chats 表中的
// model_id 可能指向已不存在的模型（chats 无外键约束），使用该会话会触发
// 'Model not found'。修复方案：导入后扫描 chats，将悬空的 model_id 重置为
// 合理的默认模型。这里直接测试 reconcileChatModelReferences()。

ModelEntity _model(int id) => ModelEntity(
      id: id,
      name: 'm$id',
      modelId: 'm$id',
      providerId: 1,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

ChatEntity _chat({required int id, required int modelId}) => ChatEntity(
      id: id,
      title: 'chat $id',
      modelId: modelId,
      sentinelId: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

/// 伪 ModelRepository：返回受控的模型列表。
class _FakeModelRepository extends ModelRepository {
  _FakeModelRepository(this.models);

  final List<ModelEntity> models;

  @override
  Future<List<ModelEntity>> getAllModels() async => models;
}

/// 伪 ChatRepository：内存中保存 chats，记录 updateChat 调用以便断言。
class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository(this.chats);

  final List<ChatEntity> chats;
  final List<int> updatedChatIds = [];

  @override
  Future<List<ChatEntity>> getAllChats() async => List.of(chats);

  @override
  Future<void> updateChat(ChatEntity chat) async {
    updatedChatIds.add(chat.id!);
    final index = chats.indexWhere((c) => c.id == chat.id);
    if (index != -1) chats[index] = chat;
  }
}

class _FakeProviderRepository extends ProviderRepository {}

class _FakeSentinelRepository extends SentinelRepository {}

SettingViewModel _vm({
  required List<ModelEntity> models,
  required _FakeChatRepository chatRepository,
}) {
  return SettingViewModel(
    modelRepository: _FakeModelRepository(models),
    chatRepository: chatRepository,
    providerRepository: _FakeProviderRepository(),
    sentinelRepository: _FakeSentinelRepository(),
  );
}

void main() {
  test('C6: 悬空的 model_id 被重置为有效的 chatModelId', () async {
    final chat = _chat(id: 100, modelId: 999); // 999 不存在
    final chatRepo = _FakeChatRepository([chat]);
    final vm = _vm(
      models: [_model(1), _model(2)],
      chatRepository: chatRepo,
    );
    vm.chatModelId.value = 2; // 有效的默认模型

    await vm.reconcileChatModelReferences();

    expect(chatRepo.updatedChatIds, [100]);
    expect(chatRepo.chats.single.modelId, 2);
  });

  test('C6: 当 chatModelId 本身无效时，重置为第一个可用模型', () async {
    final chat = _chat(id: 100, modelId: 999); // 999 不存在
    final chatRepo = _FakeChatRepository([chat]);
    final vm = _vm(
      models: [_model(5), _model(6)],
      chatRepository: chatRepo,
    );
    vm.chatModelId.value = 0; // 默认且无效

    await vm.reconcileChatModelReferences();

    expect(chatRepo.updatedChatIds, [100]);
    expect(chatRepo.chats.single.modelId, 5); // 第一个可用模型
  });

  test('C6: 有效 model_id 的会话不被修改', () async {
    final validChat = _chat(id: 100, modelId: 1);
    final danglingChat = _chat(id: 200, modelId: 999);
    final chatRepo = _FakeChatRepository([validChat, danglingChat]);
    final vm = _vm(
      models: [_model(1), _model(2)],
      chatRepository: chatRepo,
    );
    vm.chatModelId.value = 2;

    await vm.reconcileChatModelReferences();

    // 仅悬空会话被更新；有效会话保持不变。
    expect(chatRepo.updatedChatIds, [200]);
    final stillValid = chatRepo.chats.firstWhere((c) => c.id == 100);
    expect(stillValid.modelId, 1);
    final fixed = chatRepo.chats.firstWhere((c) => c.id == 200);
    expect(fixed.modelId, 2);
  });

  test('C6: 没有任何模型时不执行任何操作且不抛出', () async {
    final chat = _chat(id: 100, modelId: 999);
    final chatRepo = _FakeChatRepository([chat]);
    final vm = _vm(
      models: [],
      chatRepository: chatRepo,
    );
    vm.chatModelId.value = 0;

    await vm.reconcileChatModelReferences();

    expect(chatRepo.updatedChatIds, isEmpty);
    expect(chatRepo.chats.single.modelId, 999); // 保持原样
  });
}
