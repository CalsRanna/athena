import 'package:athena_gui/page/mobile/home/component/card_tile.dart';
import 'package:athena_gui/page/mobile/home/component/new_chat_button.dart';
import 'package:athena_gui/page/mobile/home/component/recent_chat_list_view.dart';
import 'package:athena_gui/page/mobile/home/component/section_title.dart';
import 'package:athena_gui/page/mobile/home/component/sentinel_list_view.dart';
import 'package:athena_gui/page/mobile/home/component/welcome.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/experience_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

@RoutePage()
class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _MobileHomePageState extends State<MobileHomePage> {
  final chatViewModel = GetIt.instance<ChatViewModel>();
  final sentinelViewModel = GetIt.instance<SentinelViewModel>();
  final experienceViewModel = GetIt.instance<ExperienceViewModel>();

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
      await experienceViewModel.load();
    } catch (e) {
      if (mounted) {
        AthenaDialog.error('Failed to load home data. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = [
      const MobileHomeWelcome(),
      const NewChatButton(),
      _buildRecentChatListView(),
      _buildExperiencesListView(),
      _buildSentinelListView(),
    ];
    final body = SingleChildScrollView(
      child: Column(spacing: 24, children: children),
    );
    return AthenaScaffold(body: body);
  }

  Widget _buildExperiencesListView() {
    return SignalBuilder(
      builder: (context) {
        final experiences = experienceViewModel.experiences.value
            .take(10)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            SectionTitle(
              'Experiences',
              onTap: () => navigateExperienceList(context),
            ),
            if (experiences.isNotEmpty)
              CardListView(
                itemCount: experiences.length,
                itemBuilder: (_, index) {
                  final experience = experiences[index];
                  return CardTile(
                    icon: LucideIcons.brain,
                    name: experience.lesson,
                    description:
                        '${experienceViewModel.ownerLabel(experience)} · ${_formatDate(experience.createdAt)}',
                    onTap: () => MobileExperienceDetailRoute(
                      experience: experience,
                    ).push<void>(context),
                  );
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'No experiences yet',
                  style: AthenaTextStyle.caption.copyWith(
                    color: context.athenaColors.textWeak,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void navigateExperienceList(BuildContext context) {
    const MobileExperienceListRoute().push<void>(context);
  }

  String _formatDate(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}';
  }

  Widget _buildSentinelListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        SectionTitle('Sentinel', onTap: () => navigateSentinelList(context)),
        SentinelListView(sentinelViewModel: sentinelViewModel),
      ],
    );
  }

  Widget _buildRecentChatListView() {
    return Column(
      spacing: 8,
      children: [
        SectionTitle('Session history', onTap: () => navigateChatList(context)),
        SignalBuilder(
          builder: (_) => RecentChatListView(
            chatHistories: chatViewModel.recentChatHistories.value,
            viewModel: chatViewModel,
          ),
        ),
      ],
    );
  }

  void navigateChatList(BuildContext context) {
    const MobileChatListRoute().push<void>(context);
  }

  void navigateSentinelList(BuildContext context) {
    const MobileSentinelListRoute().push<void>(context);
  }
}
