import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/service-config.dart';

class TabRecordsSelectionAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final int selectedCount;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onSelectAll;
  final VoidCallback onDuplicate;
  final VoidCallback? onMoveToWallet;

  const TabRecordsSelectionAppBar({
    Key? key,
    required this.selectedCount,
    required this.onClose,
    required this.onDelete,
    required this.onSelectAll,
    required this.onDuplicate,
    this.onMoveToWallet,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onClose,
      ),
      title: Text("$selectedCount ${"selected".i18n}"),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: "Delete".i18n,
          onPressed: selectedCount > 0 ? onDelete : null,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'select_all') {
              onSelectAll();
            } else if (value == 'duplicate') {
              onDuplicate();
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
    );
  }
}
