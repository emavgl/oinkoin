import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/records/components/styled_popup_menu_button.dart';
import 'package:piggybank/services/service-config.dart';

import '../../helpers/records-utility-functions.dart';
import '../controllers/tab_records_controller.dart';
import 'styled_action_buttons.dart';

class TabRecordsAppBar extends StatelessWidget {
  final TabRecordsController controller;
  final bool isAppBarExpanded;
  final String profileName;
  final VoidCallback onProfileTapped;
  final VoidCallback onDatePickerPressed;
  final VoidCallback onStatisticsPressed;
  final VoidCallback onSearchPressed;
  final Function(int) onMenuItemSelected;

  // Select-mode props (all optional — only used when isSelectMode is true)
  final bool isSelectMode;
  final int selectedCount;
  final VoidCallback? onClose;
  final VoidCallback? onDelete;
  final VoidCallback? onSelectAll;
  final VoidCallback? onDuplicate;
  final VoidCallback? onMoveToWallet;

  const TabRecordsAppBar({
    Key? key,
    required this.controller,
    required this.isAppBarExpanded,
    required this.profileName,
    required this.onProfileTapped,
    required this.onDatePickerPressed,
    required this.onStatisticsPressed,
    required this.onSearchPressed,
    required this.onMenuItemSelected,
    this.isSelectMode = false,
    this.selectedCount = 0,
    this.onClose,
    this.onDelete,
    this.onSelectAll,
    this.onDuplicate,
    this.onMoveToWallet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isSelectMode) {
      return _buildSelectionSliverAppBar(context);
    }

    final headerFontSize = controller.getHeaderFontSize();
    final headerPaddingBottom = controller.getHeaderPaddingBottom();
    final canShiftBack = controller.canShiftBack();
    final canShiftForward = controller.canShiftForward();

    return SliverAppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
      automaticallyImplyLeading: false,
      leading:
          (profileName.isNotEmpty && isAppBarExpanded) ? _buildLeading() : null,
      actions: _buildActions(),
      pinned: true,
      expandedHeight: MediaQuery.of(context).size.height * 0.20 < 180.0
          ? 180.0
          : MediaQuery.of(context).size.height * 0.20,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const <StretchMode>[
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

  Widget _buildSelectionSliverAppBar(BuildContext context) {
    // Keep the same expandedHeight as normal mode to avoid a scroll-area jump.
    final expandedHeight = MediaQuery.of(context).size.height * 0.20 < 180.0
        ? 180.0
        : MediaQuery.of(context).size.height * 0.20;

    return SliverAppBar(
      elevation: 0,
      forceElevated: true,
      backgroundColor: Theme.of(context).primaryColor,
      automaticallyImplyLeading: false,
      pinned: true,
      expandedHeight: expandedHeight,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: onClose,
      ),
      title: Text(
        "$selectedCount ${"selected".i18n}",
        style: const TextStyle(color: Colors.white),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          tooltip: "Delete".i18n,
          onPressed: selectedCount > 0 ? onDelete : null,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'select_all') {
              onSelectAll?.call();
            } else if (value == 'duplicate') {
              onDuplicate?.call();
            } else if (value == 'move_wallet') {
              onMoveToWallet?.call();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'select_all',
              child: Text('Select all'.i18n),
            ),
            PopupMenuItem(
              value: 'duplicate',
              child: Text('Duplicate'.i18n),
            ),
            if (ServiceConfig.isPremium)
              PopupMenuItem(
                value: 'move_wallet',
                child: Text('Move to wallet'.i18n),
              ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildBackground(),
      ),
    );
  }

  /// Profile button with icon and initials in the AppBar leading slot.
  Widget _buildLeading() {
    return Row(
      children: [
        StyledActionButton(
          icon: Icons.person,
          onPressed: onProfileTapped,
          semanticsId: 'profile',
        ),
      ],
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
        onPressed: () => controller.shiftInterval(direction),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildBackground() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withAlpha((255.0 * 0.1).round()),
        BlendMode.srcATop,
      ),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.cover,
            image: getBackgroundImage(controller.backgroundImageIndex),
          ),
        ),
      ),
    );
  }

  EdgeInsets _getTitlePadding(
      double headerPaddingBottom, bool canShiftBack, bool canShiftForward) {
    if (!isAppBarExpanded) {
      // When collapsed the title sits in the toolbar alongside the leading
      // widget (56 dp) — use the standard Material offset (56 + 16 = 72) so
      // the text doesn't slide behind the profile circle.
      return EdgeInsets.fromLTRB(15, 15, 15, headerPaddingBottom);
    }
    return EdgeInsets.fromLTRB(
      canShiftBack ? 0 : 15,
      15,
      canShiftForward ? 0 : 15,
      headerPaddingBottom,
    );
  }
}
