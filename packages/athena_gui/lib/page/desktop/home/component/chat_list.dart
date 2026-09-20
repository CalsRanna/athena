import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_gui/page/desktop/home/component/chat_context_menu.dart';
import 'package:athena_gui/router/router.gr.dart';
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
      // 侧栏结构对齐 Codex：上方是会话列表（置顶 / 其余分两组），
      // 底部常驻一个账号/设置页脚。
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
          const _SidebarFooter(),
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
      if (pinned.isNotEmpty) ...[
        const _SidebarGroup('Pinned'),
        ...pinned,
      ],
      if (rest.isNotEmpty) ...[
        const _SidebarGroup('Chats'),
        ...rest,
      ],
    ];
  }

  Widget _buildGroupLabel(BuildContext context, String label) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textWeak,
          fontSize: AthenaFontSize.caption,
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
  ) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    if (chatViewModel.selection.isMultiSelect.value) {
      var contextMenu = DesktopChatContextMenu(
        chat: chat,
        offset: details.globalPosition,
        multiSelect: true,
        selectedCount: chatViewModel.selection.selectedChatIds.value.length,
        onDestroyed: () => _handleBatchDelete(context, chatViewModel, chats),
      );
      DesktopContextMenuManager.instance.show(context, contextMenu);
    } else {
      var contextMenu = DesktopChatContextMenu(
        chat: chat,
        offset: details.globalPosition,
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
          style: TextStyle(
            color: colors.textWeak,
            decoration: TextDecoration.none,
            fontSize: AthenaFontSize.label,
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
        ),
      );
    });
  }
}

class _ChatTile extends StatefulWidget {
  final bool active;
  final ChatEntity chat;
  final bool isRenaming;

  /// 该对话的 Agent 正在后台运行（在列表上持续可见的指示）。
  final bool streaming;
  final void Function()? onTap;
  final void Function(TapUpDetails)? onSecondaryTap;
  final bool selected;
  const _ChatTile({
    this.active = false,
    required this.chat,
    this.isRenaming = false,
    this.streaming = false,
    this.onTap,
    this.onSecondaryTap,
    this.selected = false,
  });

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    Widget? trailing;
    if (widget.isRenaming) {
      trailing = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.textPrimary,
        ),
      );
    } else if (widget.streaming) {
      trailing = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.textSecondary,
        ),
      );
    } else if (widget.chat.pinned) {
      trailing = Icon(
        HugeIcons.strokeRoundedPinLocation03,
        color: colors.textPrimary,
        size: 16,
      );
    }
    return DesktopMenuTile(
      active: widget.active || widget.selected,
      label: widget.chat.title,
      trailing: trailing,
      onTap: widget.onTap,
      onSecondaryTap: widget.onSecondaryTap,
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

/// 侧栏底部常驻页脚：应用标识 + 设置入口。
///
/// 对齐 Codex 的账号页脚位置；Athena 没有账号体系，这里承担设置入口，
/// 因此顶栏不再重复放设置按钮。
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AthenaRadius.pill),
            child: Image.asset(
              'asset/image/launcher_icon_ios_512x512.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              height: 24,
              width: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Athena',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AthenaFontSize.label,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _FooterIconButton(
            icon: HugeIcons.strokeRoundedSettings01,
            onTap: () => DesktopSettingProviderRoute().push(context),
          ),
        ],
      ),
    );
  }
}

class _FooterIconButton extends StatelessWidget {
  final IconData icon;
  final void Function() onTap;
  const _FooterIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: colors.iconSecondary),
        ),
      ),
    );
  }
}

/// 侧栏顶部导航块。
///
/// Codex 的侧栏在会话分组之上还有一段导航行（New chat / Scheduled / …）。
/// Athena 只有"新建会话"这一项有对应能力，就只放它——不摆没有行为的入口。
/// 这一块同时替代了旧版悬在画布上的那枚新建铅笔图标。
class _SidebarNav extends StatelessWidget {
  final void Function()? onCreateChat;
  const _SidebarNav({this.onCreateChat});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: DesktopMenuTile(
        active: false,
        label: 'New chat',
        leading: const Icon(HugeIcons.strokeRoundedPencilEdit02),
        trailing: Icon(
          HugeIcons.strokeRoundedAdd01,
          size: 15,
          color: colors.iconSecondary,
        ),
        onTap: onCreateChat,
      ),
    );
  }
}
