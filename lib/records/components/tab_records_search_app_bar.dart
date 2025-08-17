import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/records/components/styled_popup_menu_button.dart';

import '../controllers/tab_records_controller.dart';
import 'styled_action_buttons.dart';

class TabRecordsSearchAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final TabRecordsController controller;
  final VoidCallback onBackPressed;
  final VoidCallback onDatePickerPressed;
  final VoidCallback onStatisticsPressed;
  final Function(int) onMenuItemSelected;
  final VoidCallback onFilterPressed;

  const TabRecordsSearchAppBar({
    Key? key,
    required this.controller,
    required this.onBackPressed,
    required this.onDatePickerPressed,
    required this.onStatisticsPressed,
    required this.onMenuItemSelected,
    required this.onFilterPressed,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight * 2);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).primaryColor,
      leading: _buildBackButton(),
      title: Text(
        controller.header,
        style: TextStyle(
          color: Colors.white,
          fontSize: controller.getHeaderFontSize(),
        ),
      ),
      actions: _buildActions(),
      bottom: _buildSearchTextField(),
    );
  }

  Widget _buildBackButton() {
    return StyledActionButton(
      icon: Icons.arrow_back,
      onPressed: onBackPressed,
      scaleFactor: 1.0,
    );
  }

  List<Widget> _buildActions() {
    const double actionButtonScale = 1.0;

    return <Widget>[
      StyledActionButton(
        icon: Icons.calendar_today,
        onPressed: onDatePickerPressed,
        semanticsId: 'select-date',
        scaleFactor: actionButtonScale,
      ),
      StyledActionButton(
        icon: Icons.donut_small,
        onPressed: onStatisticsPressed,
        semanticsId: 'statistics',
        scaleFactor: actionButtonScale,
      ),
      StyledPopupMenuButton(
        onSelected: onMenuItemSelected,
        scaleFactor: actionButtonScale,
      ),
    ];
  }

  PreferredSize _buildSearchTextField() {
    const double scaleFactor = 1.0;

    final double baseIconSize = 24.0 * scaleFactor;
    final double fontSize = 18.0 * scaleFactor;
    final double iconContainerSize = 48.0 * scaleFactor;
    final double horizontalPadding = 16.0 * scaleFactor;
    final double verticalPadding = 14.0 * scaleFactor;
    final double cursorWidth = 2.0 * scaleFactor;
    final double cursorHeight = 20.0 * scaleFactor;
    final double spacing = 8.0 * scaleFactor;
    final double toolbarHeight = kToolbarHeight * scaleFactor;

    return PreferredSize(
      preferredSize: Size.fromHeight(toolbarHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: controller.searchController,
                cursorColor: Colors.white,
                cursorWidth: cursorWidth,
                cursorHeight: cursorHeight,
                decoration: InputDecoration(
                  hintText: 'Search records...'.i18n,
                  hintStyle: TextStyle(
                    color: Colors.white70,
                    fontSize: fontSize,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white,
                    size: baseIconSize,
                  ),
                  prefixIconConstraints: BoxConstraints(
                    minWidth: iconContainerSize,
                    minHeight: iconContainerSize,
                  ),
                  suffixIcon: controller.searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.white,
                            size: baseIconSize,
                          ),
                          onPressed: () {
                            controller.searchController.clear();
                          },
                          constraints: BoxConstraints(
                            minWidth: iconContainerSize,
                            minHeight: iconContainerSize,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  isDense: true,
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  height: 1.2,
                ),
                textAlignVertical: TextAlignVertical.center,
              ),
            ),
            SizedBox(width: spacing),
            StyledActionButton(
              icon: Icons.filter_list,
              onPressed: onFilterPressed,
              tooltip: 'Filter records'.i18n,
              scaleFactor: scaleFactor,
            ),
          ],
        ),
      ),
    );
  }
}
