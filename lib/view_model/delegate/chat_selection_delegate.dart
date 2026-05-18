import 'package:athena/entity/chat_entity.dart';
import 'package:signals/signals.dart';

/// 聊天多选与重命名 UI 交互状态管理
class ChatSelectionDelegate {
  // 多选状态
  final selectedChatIds = setSignal<int>({});
  final lastSelectedIndex = signal<int?>(null);

  // AI 重命名状态
  final renamingChatIds = setSignal<int>({});
  final renamingTitle = signal<String>('');

  late final isMultiSelect = computed(() {
    return selectedChatIds.value.length > 1;
  });

  /// 清空多选状态
  void clearSelection() {
    selectedChatIds.value = {};
    lastSelectedIndex.value = null;
  }

  /// 切换单个对话的选中状态 (Cmd/Ctrl+Click)
  void toggleChatSelection(int chatId, int index) {
    var newSet = Set<int>.from(selectedChatIds.value);
    if (newSet.contains(chatId)) {
      newSet.remove(chatId);
      if (newSet.isEmpty) {
        lastSelectedIndex.value = null;
      }
    } else {
      newSet.add(chatId);
      lastSelectedIndex.value = index;
    }
    selectedChatIds.value = newSet;
  }

  /// 范围选择 (Shift+Click)
  void rangeSelectChats(int endIndex, List<ChatEntity> chats) {
    if (selectedChatIds.value.isEmpty && lastSelectedIndex.value == null) {
      return;
    }

    int? firstSelectedIndex;
    if (selectedChatIds.value.isNotEmpty) {
      for (var i = 0; i < chats.length; i++) {
        if (selectedChatIds.value.contains(chats[i].id)) {
          firstSelectedIndex = i;
          break;
        }
      }
    }

    var startIndex = firstSelectedIndex ?? lastSelectedIndex.value;
    if (startIndex == null) return;

    var start = startIndex;
    var end = endIndex;
    if (start > end) {
      var temp = start;
      start = end;
      end = temp;
    }

    var newSet = Set<int>.from(selectedChatIds.value);
    for (var i = start; i <= end; i++) {
      if (i < chats.length) {
        var chatId = chats[i].id;
        if (chatId != null) {
          newSet.add(chatId);
        }
      }
    }
    selectedChatIds.value = newSet;
  }

  /// 初始化 lastSelectedIndex
  void initLastSelectedIndex(ChatEntity? currentChat, List<ChatEntity> chats) {
    if (lastSelectedIndex.value == null && currentChat != null) {
      var index = chats.indexWhere((c) => c.id == currentChat.id);
      if (index >= 0) {
        lastSelectedIndex.value = index;
      }
    }
  }

  /// 开始 AI 重命名
  void startRenaming(int chatId) {
    renamingChatIds.value = {...renamingChatIds.value, chatId};
  }

  /// 结束 AI 重命名
  void stopRenaming(int chatId) {
    var newSet = Set<int>.from(renamingChatIds.value);
    newSet.remove(chatId);
    renamingChatIds.value = newSet;
  }
}
