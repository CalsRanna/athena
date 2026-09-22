import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/widget/settings_nav.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// 设置分区。
///
/// 用枚举而不是列表下标：导航带搜索过滤，过滤后下标会变，
/// **下标不能当路由标识**（旧的 `int index` 就踩过这个前提）。
enum SettingSection {
  provider,
  defaultModel,
  agent,
  sentinel,
  skill,
  experience,
  general,
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

/// 桌面端设置：Claude 桌面端设置面板的复刻。
///
/// 版式（数值与来源见 `theme/athena_settings.dart`）：
/// - **居中浮层**（最大宽 1024、上下留白 44、圆角 12）+ 40% 黑遮罩，右上角关闭；
///   路由是**非透明**的，所以面板浮在应用之上而不是整窗替换。
/// - **左栏 192**：搜索框 + 分组标题 + 图标行（行高 32、选中底 `#E3E3E2`）。
/// - **右栏纯白内容区**：顶部 60 的标题带（关闭键 / 返回链接）、分区标题、
///   行（标签 + 说明 + 右侧控件）、行间 1px `#F3F3F3` 发丝线。
///
/// **没有第二列导航**：Claude 的一个导航项对应同一内容区里的多个分区。
/// Providers / Sentinels / Skills / Experiences 这类条目集合用**单列列表 →
/// 钻取详情**（标题带里出现 `← 返回`）承载，而不是再开一列。
@RoutePage()
class DesktopSettingPage extends StatefulWidget {
  const DesktopSettingPage({super.key});

  @override
  State<DesktopSettingPage> createState() => _DesktopSettingPageState();
}

class _DesktopSettingPageState extends State<DesktopSettingPage> {
  static final groups = <_SettingGroup>[
    _SettingGroup('Settings', [
      _SettingEntry(
        SettingSection.provider,
        'Providers',
        HugeIcons.strokeRoundedPowerService,
        keywords: ['api key', 'api url', 'models', 'models.dev', 'sync'],
      ),
      _SettingEntry(
        SettingSection.defaultModel,
        'Default models',
        HugeIcons.strokeRoundedAiBrain01,
        keywords: ['chat', 'topic naming', 'sentinel metadata'],
      ),
      _SettingEntry(
        SettingSection.agent,
        'Agent',
        HugeIcons.strokeRoundedAiSetting,
        keywords: [
          'approval',
          'permissions',
          'iterations',
          'retries',
          'brave',
          'web search',
        ],
      ),
    ]),
    _SettingGroup('Customize', [
      _SettingEntry(
        SettingSection.sentinel,
        'Sentinels',
        HugeIcons.strokeRoundedArtificialIntelligence03,
        keywords: ['prompt', 'persona', 'system prompt'],
      ),
      _SettingEntry(
        SettingSection.skill,
        'Skills',
        HugeIcons.strokeRoundedBook01,
        keywords: ['instructions'],
      ),
      _SettingEntry(
        SettingSection.experience,
        'Experiences',
        HugeIcons.strokeRoundedAiBrain02,
        keywords: ['lesson', 'memory', 'archive'],
      ),
    ]),
    _SettingGroup('Desktop app', [
      _SettingEntry(
        SettingSection.general,
        'General',
        HugeIcons.strokeRoundedSettings03,
        keywords: [
          'theme',
          'appearance',
          'font size',
          'export',
          'import',
          'reset',
          'storage',
        ],
      ),
      _SettingEntry(
        SettingSection.about,
        'About Athena',
        HugeIcons.strokeRoundedInformationCircle,
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
    var search = AthenaSettingsSearchField(
      controller: searchController,
      onChanged: _handleSearch,
    );
    var children = [search, ..._buildGroups(context)];
    return AthenaSettingsNav(children: children);
  }

  List<Widget> _buildGroups(BuildContext context) {
    var visible = <Widget>[];
    for (final group in groups) {
      var entries = group.entries.where(_matches).toList();
      if (entries.isEmpty) continue;
      var items = [
        for (final entry in entries)
          AthenaSettingsNavItem(
            active: entry.section == section,
            icon: entry.icon,
            label: entry.label,
            onTap: () => openSection(entry.section),
          ),
      ];
      visible.add(
        AthenaSettingsNavGroup(title: group.title, children: items),
      );
    }
    if (visible.isEmpty) return [_buildNoResult(context)];
    return visible;
  }

  Widget _buildNoResult(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textWeak,
      fontSize: AthenaSettings.fontSizeForEmptySearch,
      height: 1.5,
    );
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
    for (final match in router.currentSegments.reversed) {
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
    if (name == DesktopSettingDefaultModelRoute.name) {
      return SettingSection.defaultModel;
    }
    if (name == DesktopSettingAgentRoute.name) return SettingSection.agent;
    if (name == DesktopSettingSentinelRoute.name) {
      return SettingSection.sentinel;
    }
    if (name == DesktopSettingSkillRoute.name) return SettingSection.skill;
    if (name == DesktopSettingExperienceRoute.name) {
      return SettingSection.experience;
    }
    if (name == DesktopSettingGeneralRoute.name) {
      return SettingSection.general;
    }
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
    var route = switch (section) {
      SettingSection.provider => const DesktopSettingProviderRoute(),
      SettingSection.defaultModel => const DesktopSettingDefaultModelRoute(),
      SettingSection.agent => const DesktopSettingAgentRoute(),
      SettingSection.sentinel => const DesktopSettingSentinelRoute(),
      SettingSection.skill => const DesktopSettingSkillRoute(),
      SettingSection.experience => const DesktopSettingExperienceRoute(),
      SettingSection.general => const DesktopSettingGeneralRoute(),
      SettingSection.about => const DesktopSettingAboutRoute(),
    };
    AutoRouter.of(context).replace(route);
  }
}
