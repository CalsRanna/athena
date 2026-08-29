import 'package:athena_gui/page/mobile/home/component/new_chat_button.dart';
import 'package:athena_gui/page/mobile/home/component/recent_chat_list_view.dart';
import 'package:athena_gui/page/mobile/home/component/section_title.dart';
import 'package:athena_gui/page/mobile/home/component/sentinel_list_view.dart';
import 'package:athena_gui/page/mobile/home/component/shortcut_list_view.dart';
import 'package:athena_gui/page/mobile/home/component/welcome.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/shortcut_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/error_boundary.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _MobileHomePageState extends State<MobileHomePage> {
  final chatViewModel = GetIt.instance<ChatViewModel>();
  final sentinelViewModel = GetIt.instance<SentinelViewModel>();
  final shortcutViewModel = GetIt.instance<ShortcutViewModel>();

  @override
  void initState() {
    super.initState();
    _initializeViewModels();
  }

  Future<void> _initializeViewModels() async {
    try {
      await GetIt.instance<SettingViewModel>().initSignals();
      await chatViewModel.getChats();
      await sentinelViewModel.getSentinels();
      await shortcutViewModel.getShortcuts();
    } catch (e) {
      if (mounted) {
        AthenaDialog.error('Failed to load home data. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var children = [
      MobileHomeWelcome(),
      const NewChatButton(),
      _buildRecentChatListView(),
      _buildShortcutListView(),
      _buildSentinelListView(),
    ];
    var body = AthenaErrorBoundary(
      message: 'Home page encountered an error',
      onRetry: _initializeViewModels,
      child: SingleChildScrollView(
        child: Column(spacing: 24, children: children),
      ),
    );
    return AthenaScaffold(body: body);
  }

  Widget _buildSentinelListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        SectionTitle('Sentinel', onTap: () => navigateSentinelList(context)),
        SizedBox(
          height: 156,
          child: SentinelListView(sentinelViewModel: sentinelViewModel),
        ),
      ],
    );
  }

  Widget _buildShortcutListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        const SectionTitle('Shortcut'),
        SizedBox(
          height: 160,
          child: ShortcutListView(
            shortcutViewModel: shortcutViewModel,
            sentinelViewModel: sentinelViewModel,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentChatListView() {
    return Column(
      spacing: 8,
      children: [
        SectionTitle('Chat history', onTap: () => navigateChatList(context)),
        SizedBox(
          height: 52,
          child: Watch(
            (_) => RecentChatListView(
              chatHistories: chatViewModel.recentChatHistories.value,
              viewModel: chatViewModel,
            ),
          ),
        ),
      ],
    );
  }

  void navigateChatList(BuildContext context) {
    MobileChatListRoute().push(context);
  }

  void navigateSentinelList(BuildContext context) {
    MobileSentinelListRoute().push(context);
  }
}
