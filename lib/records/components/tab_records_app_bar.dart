import 'package:flutter/material.dart';
import 'package:piggybank/records/components/styled_popup_menu_button.dart';

import '../../helpers/records-utility-functions.dart';
import '../controllers/tab_records_controller.dart';
import 'styled_action_buttons.dart';

class TabRecordsAppBar extends StatelessWidget {
  final TabRecordsController controller;
  final bool isAppBarExpanded;
  final VoidCallback onDatePickerPressed;
  final VoidCallback onStatisticsPressed;
  final VoidCallback onSearchPressed;
  final Function(int) onMenuItemSelected;

  const TabRecordsAppBar({
    Key? key,
    required this.controller,
    required this.isAppBarExpanded,
    required this.onDatePickerPressed,
    required this.onStatisticsPressed,
    required this.onSearchPressed,
    required this.onMenuItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final headerFontSize = controller.getHeaderFontSize();
    final headerPaddingBottom = controller.getHeaderPaddingBottom();
    final canShiftBack = controller.canShiftBack();
    final canShiftForward = controller.canShiftForward();

    return SliverAppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
      actions: _buildActions(),
      pinned: true,
      expandedHeight: 180.0,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: <StretchMode>[
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
          StretchMode.fadeTitle,
        ],
        centerTitle: false,
        titlePadding: _getTitlePadding(
            headerPaddingBottom, canShiftBack, canShiftForward),
        title: _buildTitle(headerFontSize, canShiftBack, canShiftForward),
        background: _buildBackground(),
      ),
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
      StyledActionButton(
        icon: Icons.search,
        onPressed: onSearchPressed,
        semanticsId: 'search-button',
        scaleFactor: actionButtonScale,
      ),
      StyledPopupMenuButton(
        onSelected: onMenuItemSelected,
        scaleFactor: actionButtonScale,
      ),
    ];
  }

  Widget _buildTitle(
      double headerFontSize, bool canShiftBack, bool canShiftForward) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (isAppBarExpanded && canShiftBack)
          _buildShiftButton(Icons.arrow_left, -1),
        Expanded(
          child: Semantics(
            identifier: 'date-text',
            child: Text(
              controller.header,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: TextStyle(color: Colors.white, fontSize: headerFontSize),
            ),
          ),
        ),
        if (isAppBarExpanded && canShiftForward)
          _buildShiftButton(Icons.arrow_right, 1),
      ],
    );
  }

  Widget _buildShiftButton(IconData icon, int direction) {
    return SizedBox(
      height: 30,
      width: 30,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: () => controller.shiftMonthOrYear(direction),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildBackground() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.1),
        BlendMode.srcATop,
      ),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.cover,
            image: getBackgroundImage(),
          ),
        ),
      ),
    );
  }

  EdgeInsets _getTitlePadding(
      double headerPaddingBottom, bool canShiftBack, bool canShiftForward) {
    return !isAppBarExpanded
        ? EdgeInsets.fromLTRB(15, 15, 15, headerPaddingBottom)
        : EdgeInsets.fromLTRB(
            canShiftBack ? 0 : 15,
            15,
            canShiftForward ? 0 : 15,
            headerPaddingBottom,
          );
  }
}
