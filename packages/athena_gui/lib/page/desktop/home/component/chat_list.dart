import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/page/desktop/home/component/home_shortcuts.dart';
import 'package:athena_gui/page/desktop/home/component/sidebar_footer.dart';
import 'package:athena_gui/page/desktop/home/component/status_dot.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
    return SignalBuilder(
      builder: (context) {
        final chats = chatViewModel.chats.value;
        chatViewModel.initLastSelectedIndex();
        // 侧栏结构：上方是会话列表（置顶 / 其余分两组），
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
                        _SidebarEntry(:final index, :final chat) =>
                          _itemBuilder(context, chats, index, chat),
                      },
                      itemCount: items.length,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    ),
            ),
            DesktopSidebarFooter(onNewSession: onCreateChat),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final colors = context.athenaColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No sessions yet',
          style: AthenaTextStyle.caption.copyWith(
            color: colors.textWeak,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupLabel(BuildContext context, String label) {
    final colors = context.athenaColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: Text(
        label,
        style: AthenaTextStyle.caption.copyWith(color: colors.textWeak),
      ),
    );
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

  void _handleBatchDelete(
    BuildContext context,
    ChatViewModel viewModel,
    List<ChatEntity> chats,
  ) {
    final selectedChats = chats
        .where((c) => viewModel.selection.selectedChatIds.value.contains(c.id))
        .toList();
    if (selectedChats.isNotEmpty) {
      onBatchDestroyed?.call(selectedChats);
      // clearSelection is called in batchDestroyChats after confirmation
    }
  }

  void _handleTap(ChatViewModel viewModel, ChatEntity chat, int index) {
    final isMetaPressed =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

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

  Widget _itemBuilder(
    BuildContext context,
    List<ChatEntity> chats,
    int index,
    ChatEntity chat,
  ) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    return SignalBuilder(
      builder: (context) {
        final selectedChat = chatViewModel.currentChat.value;
        final selectedIds = chatViewModel.selection.selectedChatIds.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _ChatTile(
            active: selectedChat?.id == chat.id,
            chat: chat,
            streaming: chatViewModel.isStreamingChat(chat.id!),
            unread: chat.unread,
            onTap: () => _handleTap(chatViewModel, chat, index),
            onSecondaryTap: (details) =>
                _openContextMenu(context, details, chat, chats),
            selected: selectedIds.contains(chat.id),
            onMore: (offset) =>
                _openContextMenuAt(context, offset, chat, chats),
          ),
        );
      },
    );
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
      final contextMenu = _ChatContextMenu(
        chat: chat,
        offset: position,
        multiSelect: true,
        onDestroyed: () => _handleBatchDelete(context, chatViewModel, chats),
      );
      DesktopContextMenuManager.instance.show(context, contextMenu);
    } else {
      final contextMenu = _ChatContextMenu(
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
}

/// 会话行的右键菜单：右键与行尾的 `⋮` 按钮共用。
class _ChatContextMenu extends StatelessWidget {
  final ChatEntity chat;
  final bool multiSelect;
  final Offset offset;
  final void Function()? onAutoRenamed;
  final void Function()? onDestroyed;
  final void Function()? onManualRenamed;
  final void Function()? onPinned;

  const _ChatContextMenu({
    required this.chat,
    this.multiSelect = false,
    required this.offset,
    this.onAutoRenamed,
    this.onDestroyed,
    this.onManualRenamed,
    this.onPinned,
  });

  @override
  Widget build(BuildContext context) {
    final pinText = chat.pinned ? 'Unpin' : 'Pin';
    final renameSubmenu = DesktopContextMenuTileWithSubmenu(
      text: 'Rename',
      enabled: !multiSelect,
      submenuItems: [
        DesktopContextMenuSubItem(text: 'Auto Rename', onTap: onAutoRenamed),
        DesktopContextMenuSubItem(
          text: 'Manual Rename',
          onTap: onManualRenamed,
        ),
      ],
    );
    final children = [
      DesktopContextMenuTile(
        text: pinText,
        onTap: onPinned,
        enabled: !multiSelect,
      ),
      renameSubmenu,
      const DesktopContextMenuSeparator(),
      DesktopContextMenuTile(text: 'Delete', danger: true, onTap: onDestroyed),
    ];
    return DesktopContextMenu(offset: offset, width: 140, children: children);
  }
}

/// 侧栏的一条会话行。
///
/// 行本身不带浮层：悬浮预览卡只挂在轮次条上（见 `turn_indicator.dart`），
/// 会话行只有标题、运行中状态点，以及 hover 才出现的 `⋮`。
class _ChatTile extends StatelessWidget {
  final bool active;
  final ChatEntity chat;

  /// 该对话的 Agent 正在后台运行（在列表上持续可见的指示）。
  final bool streaming;

  /// 跑完时用户不在该对话、之后还没点进来过（未读圆点）。
  final bool unread;
  final void Function()? onTap;
  final void Function(TapUpDetails)? onSecondaryTap;
  final bool selected;

  /// 行尾 `⋮` 按钮被点击（位置用于锚定菜单）。
  final void Function(Offset)? onMore;
  const _ChatTile({
    this.active = false,
    required this.chat,
    this.streaming = false,
    this.unread = false,
    this.onMore,
    this.onTap,
    this.onSecondaryTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isActive = active || selected;
    final contentColor = isActive ? colors.accent : colors.textRowLabel;
    return AthenaHover(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => AnimatedContainer(
        decoration: BoxDecoration(
          color: isActive
              ? colors.surfaceSelected
              : hover
              ? colors.surfaceHover
              : colors.surfaceHover.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(AthenaRadius.row),
        ),
        duration: AthenaMotion.hover,
        // 固定高保证 hover 出现的 `⋮` 不改变行高。
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                chat.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AthenaTextStyle.body.copyWith(color: contentColor),
              ),
            ),
            // 行尾状态点：运行中优先，其次未读；hover 时让位给 `⋮`。
            if (hover && onMore != null)
              _MoreButton(onTap: onMore!)
            else if (streaming)
              const StatusDot()
            else if (unread)
              const StatusDot(unread: true),
          ],
        ),
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
    final colors = context.athenaColors;
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
            AthenaIcons.more,
            size: AthenaIcon.inlineSize,
            color: colors.iconSecondary,
          ),
        ),
      ),
    );
  }
}

/// 行尾的快捷键提示（macOS `⌘N` / 其余 `Ctrl+N`，只在 hover 时可见）。
///
/// 文案取自 [DesktopHomeShortcuts.newChatLabel]，不在这里重写平台判断。
/// 样式 `caption` + `textSecondary`：提示是辅助信息要弱一档，但得能从
/// hover 底（`surfaceHover`）上读出来——`textWeak` 在浅色下只有 3.2:1，
/// 12 号小字不合格，`textSecondary` 浅色 4.6:1 / 深色 5.7:1。
class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint();

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    return Text(
      DesktopHomeShortcuts.newChatLabel(context),
      style: AthenaTextStyle.caption.copyWith(color: colors.textSecondary),
    );
  }
}

class _SidebarEntry extends _SidebarItem {
  final int index;
  final ChatEntity chat;
  const _SidebarEntry({required this.index, required this.chat});
}

class _SidebarGroup extends _SidebarItem {
  final String label;
  const _SidebarGroup(this.label);
}

/// 侧栏列表项：分组标题或一条会话。[index] 是会话在原始列表中的绝对下标。
sealed class _SidebarItem {
  const _SidebarItem();
}

/// 侧栏顶部导航块。
///
/// 侧栏在会话分组之上还有一段导航行（New chat 等）。
/// Athena 只有"新建会话"这一项有对应能力，就只放它——不摆没有行为的入口。
class _SidebarNav extends StatelessWidget {
  final void Function()? onCreateChat;
  const _SidebarNav({this.onCreateChat});

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: AthenaHover(
        onTap: onCreateChat,
        cursor: SystemMouseCursors.click,
        builder: (context, hover) => AnimatedContainer(
          decoration: BoxDecoration(
            color: hover
                ? colors.surfaceHover
                : colors.surfaceHover.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(AthenaRadius.row),
          ),
          duration: AthenaMotion.hover,
          // 固定高保证 hover 出现的快捷键提示不改变行高。
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(
                  color: colors.textRowLabel,
                  size: AthenaIcon.regularSize,
                ),
                child: const Icon(LucideIcons.pencilLine),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'New session',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AthenaTextStyle.body.copyWith(
                    color: colors.textRowLabel,
                  ),
                ),
              ),
              // 快捷键提示只在 hover 出现，与会话行的 `⋮` 同一口径：静止行没有尾部。
              if (hover) const _ShortcutHint(),
            ],
          ),
        ),
      ),
    );
  }
}
