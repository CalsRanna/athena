import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_gui/page/desktop/home/component/chat_context_menu.dart';
import 'package:athena_gui/page/desktop/home/component/sidebar_footer.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopChatListView extends StatelessWidget {
  final void Function()? onCreateChat;
  final void Function(ChatEntity)? onAutoRenamed;
  final void Function(List<ChatEntity>)? onBatchDestroyed;
  final void Function(ChatEntity)? onDestroyed;
  final void Function(ChatEntity)? onManualRenamed;
  final void Function(ChatEntity)? onPinned;
  final void Function(ChatEntity)? onSelected;

  const DesktopChatListView({
    super.key,
    this.onCreateChat,
    this.onAutoRenamed,
    this.onBatchDestroyed,
    this.onDestroyed,
    this.onManualRenamed,
    this.onPinned,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    return Watch((context) {
      var chats = chatViewModel.chats.value;
      chatViewModel.initLastSelectedIndex();
      // 侧栏结构对齐 Claude：上方是会话列表（置顶 / 其余分两组），
      // 底部常驻一个账号式页脚（点击弹出设置 / 关于菜单）。
      final items = _buildSidebarItems(chats);
      return Column(
        children: [
          _SidebarNav(onCreateChat: onCreateChat),
          Expanded(
            child: chats.isEmpty
                ? _buildEmpty(context)
                : ListView.builder(
                    itemBuilder: (context, index) => switch (items[index]) {
                      _SidebarGroup(:final label) => _buildGroupLabel(
                        context,
                        label,
                      ),
                      _SidebarEntry(:final index, :final chat) => _itemBuilder(
                        context,
                        chats,
                        index,
                        chat,
                      ),
                    },
                    itemCount: items.length,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  ),
          ),
          const DesktopSidebarFooter(),
        ],
      );
    });
  }

  /// 置顶会话与其余会话分两组；[index] 始终是它在原始列表里的绝对下标，
  /// 供多选/范围选择复用。
  List<_SidebarItem> _buildSidebarItems(List<ChatEntity> chats) {
    final pinned = <_SidebarEntry>[];
    final rest = <_SidebarEntry>[];
    for (final (index, chat) in chats.indexed) {
      (chat.pinned ? pinned : rest).add(
        _SidebarEntry(index: index, chat: chat),
      );
    }
    return [
      if (pinned.isNotEmpty) ...[const _SidebarGroup('Pinned'), ...pinned],
      if (rest.isNotEmpty) ...[const _SidebarGroup('Recent'), ...rest],
    ];
  }

  Widget _buildGroupLabel(BuildContext context, String label) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: Text(
        label,
        style: AthenaTextStyle.label.copyWith(
          color: colors.textWeak,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _handleBatchDelete(
    BuildContext context,
    ChatViewModel viewModel,
    List<ChatEntity> chats,
  ) {
    var selectedChats = chats
        .where((c) => viewModel.selection.selectedChatIds.value.contains(c.id))
        .toList();
    if (selectedChats.isNotEmpty) {
      onBatchDestroyed?.call(selectedChats);
      // clearSelection is called in batchDestroyChats after confirmation
    }
  }

  void _handleTap(ChatViewModel viewModel, ChatEntity chat, int index) {
    var isMetaPressed =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    var isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (isMetaPressed) {
      viewModel.toggleChatSelection(chat.id!, index);
    } else if (isShiftPressed &&
        (viewModel.selection.lastSelectedIndex.value != null ||
            viewModel.selection.selectedChatIds.value.isNotEmpty)) {
      viewModel.rangeSelectChats(index);
    } else {
      viewModel.clearSelection();
      viewModel.selection.lastSelectedIndex.value = index;
      onSelected?.call(chat);
    }
  }

  void _openContextMenu(
    BuildContext context,
    TapUpDetails details,
    ChatEntity chat,
    List<ChatEntity> chats,
  ) => _openContextMenuAt(context, details.globalPosition, chat, chats);

  /// 在 [position] 处弹出会话右键菜单。右键与行尾的 `⋮` 按钮共用。
  void _openContextMenuAt(
    BuildContext context,
    Offset position,
    ChatEntity chat,
    List<ChatEntity> chats,
  ) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    if (chatViewModel.selection.isMultiSelect.value) {
      var contextMenu = DesktopChatContextMenu(
        chat: chat,
        offset: position,
        multiSelect: true,
        selectedCount: chatViewModel.selection.selectedChatIds.value.length,
        onDestroyed: () => _handleBatchDelete(context, chatViewModel, chats),
      );
      DesktopContextMenuManager.instance.show(context, contextMenu);
    } else {
      var contextMenu = DesktopChatContextMenu(
        chat: chat,
        offset: position,
        onAutoRenamed: () => onAutoRenamed?.call(chat),
        onDestroyed: () => onDestroyed?.call(chat),
        onManualRenamed: () => onManualRenamed?.call(chat),
        onPinned: () => onPinned?.call(chat),
      );
      DesktopContextMenuManager.instance.show(context, contextMenu);
    }
  }

  Widget _buildEmpty(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No chats yet',
          style: AthenaTextStyle.caption.copyWith(
            color: colors.textWeak,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _itemBuilder(
    BuildContext context,
    List<ChatEntity> chats,
    int index,
    ChatEntity chat,
  ) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    return Watch((context) {
      var selectedChat = chatViewModel.currentChat.value;
      var selectedIds = chatViewModel.selection.selectedChatIds.value;
      var renamingIds = chatViewModel.selection.renamingChatIds.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: _ChatTile(
          active: selectedChat?.id == chat.id,
          chat: chat,
          isRenaming: renamingIds.contains(chat.id),
          streaming: chatViewModel.isStreamingChat(chat.id!),
          onTap: () => _handleTap(chatViewModel, chat, index),
          onSecondaryTap: (details) =>
              _openContextMenu(context, details, chat, chats),
          selected: selectedIds.contains(chat.id),
          onMore: (offset) => _openContextMenuAt(context, offset, chat, chats),
        ),
      );
    });
  }
}

/// 侧栏的一条会话行。
///
/// 行本身不带浮层：悬浮预览卡只挂在轮次条上（见 `turn_indicator.dart`），
/// 会话行只有状态点、标题，以及 hover 才出现的 `⋮`。
class _ChatTile extends StatelessWidget {
  final bool active;
  final ChatEntity chat;
  final bool isRenaming;

  /// 该对话的 Agent 正在后台运行（在列表上持续可见的指示）。
  final bool streaming;
  final void Function()? onTap;
  final void Function(TapUpDetails)? onSecondaryTap;
  final bool selected;

  /// 行尾 `⋮` 按钮被点击（位置用于锚定菜单）。
  final void Function(Offset)? onMore;
  const _ChatTile({
    this.active = false,
    required this.chat,
    this.isRenaming = false,
    this.streaming = false,
    this.onMore,
    this.onTap,
    this.onSecondaryTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return DesktopMenuTile(
      active: active || selected,
      label: chat.title,
      // Claude 的会话行 leading 是一个状态点（hover 时加深），不是图标
      leadingBuilder: (hover) => _StatusDot(
        hover: hover,
        streaming: streaming,
        renaming: isRenaming,
        pinned: chat.pinned,
      ),
      // 尾部只在 hover 时出现：一个 `⋮` 按钮。旧版把图钉/进度圈常驻在行尾，
      // 与 Claude 的"静止行没有尾部"不符。
      hoverTrailing: onMore == null ? null : _MoreButton(onTap: onMore!),
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
    );
  }
}

/// 会话行的状态点。Claude 实测：静止 `#CAC8C4`、hover 加深到 `#8F8D89`，
/// 直径约 6 逻辑。用 `iconSecondary` 调透明度即可复现这两个档位。
class _StatusDot extends StatelessWidget {
  final bool hover;
  final bool streaming;
  final bool renaming;
  final bool pinned;

  const _StatusDot({
    required this.hover,
    required this.streaming,
    required this.renaming,
    required this.pinned,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final Color base;
    final double alpha;
    if (streaming) {
      base = colors.accent;
      alpha = 1;
    } else if (renaming) {
      base = colors.statusWarning;
      alpha = 1;
    } else {
      base = colors.iconSecondary;
      alpha = hover ? 0.75 : 0.45;
    }
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: base.withValues(alpha: alpha),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 行尾的 `⋮` 按钮（只在 hover 时可见）。
class _MoreButton extends StatelessWidget {
  final void Function(Offset) onTap;
  const _MoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
        onTap(Offset(origin.dx + (box?.size.width ?? 0), origin.dy));
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(
            HugeIcons.strokeRoundedMoreVertical,
            size: 14,
            color: colors.iconSecondary,
          ),
        ),
      ),
    );
  }
}

/// 侧栏列表项：分组标题或一条会话。[index] 是会话在原始列表中的绝对下标。
sealed class _SidebarItem {
  const _SidebarItem();
}

class _SidebarGroup extends _SidebarItem {
  final String label;
  const _SidebarGroup(this.label);
}

class _SidebarEntry extends _SidebarItem {
  final int index;
  final ChatEntity chat;
  const _SidebarEntry({required this.index, required this.chat});
}

/// 侧栏顶部导航块。
///
/// Claude 的侧栏在会话分组之上还有一段导航行（New chat 等）。
/// Athena 只有"新建会话"这一项有对应能力，就只放它——不摆没有行为的入口。
/// 这一块同时替代了旧版悬在画布上的那枚新建铅笔图标。
class _SidebarNav extends StatelessWidget {
  final void Function()? onCreateChat;
  const _SidebarNav({this.onCreateChat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: DesktopMenuTile(
        active: false,
        label: 'New chat',
        leading: const Icon(HugeIcons.strokeRoundedPencilEdit02),
        onTap: onCreateChat,
      ),
    );
  }
}
