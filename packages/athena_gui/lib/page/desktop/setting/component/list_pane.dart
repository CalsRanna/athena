import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:athena_gui/page/desktop/setting/component/nav.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

abstract interface class SettingsListOption {
  String get label;
}

class AthenaSettingsListPane<
  F extends SettingsListOption,
  S extends SettingsListOption
>
    extends StatelessWidget {
  const AthenaSettingsListPane({
    super.key,
    required this.title,
    required this.searchController,
    required this.onSearchChanged,
    required this.filterBy,
    required this.filter,
    required this.filters,
    required this.onFilterChanged,
    required this.sort,
    required this.sorts,
    required this.onSortChanged,
    required this.children,
    this.onAdd,
    this.controller,
    this.menus,
  });

  final String title;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String filterBy;
  final F filter;
  final List<F> filters;
  final ValueChanged<F> onFilterChanged;
  final S sort;
  final List<S> sorts;
  final ValueChanged<S> onSortChanged;
  final List<Widget> children;
  final VoidCallback? onAdd;
  final ScrollController? controller;
  final List<Widget>? menus;

  @override
  Widget build(BuildContext context) {
    final search = AthenaSettingsSearchField(
      controller: searchController,
      placeholder: 'Search ${title.toLowerCase()}',
      onChanged: onSearchChanged,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return AthenaSettingsPane(
          key: PageStorageKey('settings-list-$title'),
          title: title,
          controller: controller,
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ...[
                SizedBox(width: 240, child: search),
                const SizedBox(width: AthenaSpace.sm),
              ],
              _menu(
                tooltip: 'Filter by $filterBy: ${filter.label}',
                icon: filter == filters.first
                    ? LucideIcons.listFilter
                    : LucideIcons.listFilterPlus,
                options: filters,
                selected: filter,
                onChanged: onFilterChanged,
              ),
              _menu(
                tooltip: 'Sort by ${sort.label}',
                icon: LucideIcons.arrowUpDown,
                options: sorts,
                selected: sort,
                onChanged: onSortChanged,
              ),
              ...?menus,
              if (onAdd != null) ...[
                const SizedBox(width: AthenaSpace.sm),
                AthenaPrimaryButton.small(
                  onTap: onAdd,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus),
                      SizedBox(width: 4),
                      Text('Add'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          children: [
            if (compact) ...[
              AthenaSettingsInset(child: search),
              const SizedBox(height: AthenaSpace.lg),
            ],
            ...children,
          ],
        );
      },
    );
  }

  Widget _menu<T extends SettingsListOption>({
    required String tooltip,
    required IconData icon,
    required List<T> options,
    required T selected,
    required ValueChanged<T> onChanged,
  }) => Tooltip(
    message: tooltip,
    child: AthenaSettingsMenuButton(
      icon: icon,
      items: [
        for (final option in options)
          DesktopContextMenuTile(
            text: option.label,
            selected: option == selected,
            onTap: () => onChanged(option),
          ),
      ],
    ),
  );
}
