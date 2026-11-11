import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/page/desktop/setting/component/nav.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

/// 设置分区。
///
/// 用枚举而不是列表下标：导航带搜索过滤，过滤后下标会变，
/// **下标不能当路由标识**（旧的 `int index` 就踩过这个前提）。
enum SettingSection {
  agent,
  provider,
  sentinel,
  skill,
  experience,
  appearance,
  data,
  about,
}

class _SettingEntry {
  final SettingSection section;
  final String label;
  final IconData icon;

  /// 搜索时额外命中的关键词（分区里的行标签），让「api key」也能找到 Providers。
  final List<String> keywords;
  const _SettingEntry(
    this.section,
    this.label,
    this.icon, {
    this.keywords = const [],
  });
}

class _SettingGroup {
  final String title;
  final List<_SettingEntry> entries;
  const _SettingGroup(this.title, this.entries);
}

/// 桌面端设置面板。
///
/// 八个分区共用同一浮层，集合页在右侧内容区钻取详情。
@RoutePage()
class DesktopSettingPage extends StatefulWidget {
  const DesktopSettingPage({super.key});

  @override
  State<DesktopSettingPage> createState() => _DesktopSettingPageState();
}

class _DesktopSettingPageState extends State<DesktopSettingPage> {
  static final groups = <_SettingGroup>[
    const _SettingGroup('Agent', [
      _SettingEntry(
        SettingSection.agent,
        'Agent',
        LucideIcons.workflow,
        keywords: [
          'attempts',
          'retries',
          'output',
          'limit',
          'reasoning',
          'effort',
          'tools',
          'background',
          'brave',
          'web search',
        ],
      ),
      _SettingEntry(
        SettingSection.provider,
        'Providers',
        AthenaIcons.connection,
        keywords: ['api key', 'api url', 'models', 'models.dev', 'sync'],
      ),
    ]),
    const _SettingGroup('Content', [
      _SettingEntry(
        SettingSection.sentinel,
        'Sentinels',
        LucideIcons.userRound,
        keywords: ['prompt', 'persona', 'system prompt'],
      ),
      _SettingEntry(
        SettingSection.skill,
        'Skills',
        LucideIcons.bookOpen,
        keywords: ['instructions'],
      ),
      _SettingEntry(
        SettingSection.experience,
        'Experiences',
        LucideIcons.brain,
        keywords: ['lesson', 'experience', 'archive'],
      ),
    ]),
    const _SettingGroup('App', [
      _SettingEntry(
        SettingSection.appearance,
        'Appearance',
        LucideIcons.palette,
        keywords: ['theme', 'font size', 'text size'],
      ),
      _SettingEntry(
        SettingSection.data,
        'Data',
        LucideIcons.database,
        keywords: [
          'data folder',
          'reset',
          'storage',
          'snapshot',
          'snapshots',
          'tool output',
          'tool outputs',
          'cleanup',
        ],
      ),
      _SettingEntry(
        SettingSection.about,
        'About Athena',
        LucideIcons.info,
        keywords: ['version', 'license', 'github', 'issue'],
      ),
    ]),
  ];

  final searchController = TextEditingController();
  var section = SettingSection.provider;
  var query = '';

  @override
  void initState() {
    super.initState();
    // 设置页也可能被**外部**入口直接推入（侧栏页脚的 About 就是
    // `DesktopSettingAboutRoute().push(...)`）。这时不能假定停在
    // Providers——否则左栏会高亮错行。
    section = _sectionFromRouter() ?? SettingSection.provider;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AthenaSettingsPanel(
      onClose: () => Navigator.of(context).maybePop(),
      nav: _buildNav(context),
      content: const AutoRouter(),
    );
  }

  Widget _buildNav(BuildContext context) {
    final search = AthenaSettingsSearchField(
      controller: searchController,
      onChanged: _handleSearch,
    );
    return AthenaSettingsNav(search: search, children: _buildGroups(context));
  }

  List<Widget> _buildGroups(BuildContext context) {
    final visible = <Widget>[];
    for (final group in groups) {
      final entries = group.entries.where(_matches).toList();
      if (entries.isEmpty) continue;
      final items = [
        for (final entry in entries)
          AthenaSettingsNavItem(
            active: entry.section == section,
            icon: entry.icon,
            label: entry.label,
            onTap: () => openSection(entry.section),
          ),
      ];
      visible.add(AthenaSettingsNavGroup(title: group.title, children: items));
    }
    if (visible.isEmpty) return [_buildNoResult(context)];
    return visible;
  }

  Widget _buildNoResult(BuildContext context) {
    final colors = context.athenaColors;
    final textStyle = AthenaTextStyle.row.copyWith(color: colors.textWeak);
    return Padding(
      padding: const EdgeInsets.only(
        top: AthenaSettings.navGroupTopMargin,
        left: 10,
      ),
      child: Text('No results', style: textStyle),
    );
  }

  /// 从路由栈里读出当前打开的分区。
  SettingSection? _sectionFromRouter() {
    for (final match in AthenaRouter.router.currentSegments.reversed) {
      if (match.name != DesktopSettingRoute.name) continue;
      final children = match.children;
      if (children == null || children.isEmpty) return null;
      return _sectionFromName(children.last.name);
    }
    return null;
  }

  SettingSection? _sectionFromName(String? name) {
    if (name == DesktopSettingProviderRoute.name) {
      return SettingSection.provider;
    }
    if (name == DesktopSettingAgentRoute.name) return SettingSection.agent;
    if (name == DesktopSettingSentinelRoute.name) {
      return SettingSection.sentinel;
    }
    if (name == DesktopSettingSkillRoute.name) return SettingSection.skill;
    if (name == DesktopSettingExperienceRoute.name) {
      return SettingSection.experience;
    }
    if (name == DesktopSettingAppearanceRoute.name) {
      return SettingSection.appearance;
    }
    if (name == DesktopSettingDataRoute.name) return SettingSection.data;
    if (name == DesktopSettingAboutRoute.name) return SettingSection.about;
    return null;
  }

  bool _matches(_SettingEntry entry) {
    if (query.isEmpty) return true;
    if (entry.label.toLowerCase().contains(query)) return true;
    return entry.keywords.any((keyword) => keyword.contains(query));
  }

  void _handleSearch(String value) {
    setState(() => query = value.trim().toLowerCase());
  }

  void openSection(SettingSection section) {
    if (section == this.section) return;
    setState(() => this.section = section);
    final route = switch (section) {
      SettingSection.provider => const DesktopSettingProviderRoute(),
      SettingSection.agent => const DesktopSettingAgentRoute(),
      SettingSection.sentinel => const DesktopSettingSentinelRoute(),
      SettingSection.skill => const DesktopSettingSkillRoute(),
      SettingSection.experience => const DesktopSettingExperienceRoute(),
      SettingSection.appearance => const DesktopSettingAppearanceRoute(),
      SettingSection.data => const DesktopSettingDataRoute(),
      SettingSection.about => const DesktopSettingAboutRoute(),
    };
    AutoRouter.of(context).replace(route);
  }
}
