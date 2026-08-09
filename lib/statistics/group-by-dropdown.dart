import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/record-filters.dart';
import 'package:piggybank/services/service-config.dart';

/// A toggle widget that allows switching between Category, Tags, and Records views.
///
/// Displays clickable tokens for each grouping option. The visibility of each
/// option can be controlled via constructor parameters.
class GroupByDropdown extends StatelessWidget {
  final List<Record?> records;
  final GroupByType groupByType;
  final void Function(GroupByType) onGroupByTypeChanged;
  final DateTime? selectedDate;
  final String? selectedCategoryOrTag;
  final List<String>? topCategories;
  final AggregationMethod? aggregationMethod;
  final bool showRecordsToggle;
  final bool hideTagsSelection;
  final bool hideCategorySelection;
  final bool hideWalletsSelection;

  const GroupByDropdown({
    Key? key,
    required this.records,
    required this.groupByType,
    required this.onGroupByTypeChanged,
    this.selectedDate,
    this.selectedCategoryOrTag,
    this.topCategories,
    this.aggregationMethod,
    this.showRecordsToggle = false,
    this.hideTagsSelection = false,
    this.hideCategorySelection = false,
    this.hideWalletsSelection = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recordsToCheck = _getFilteredRecords();
    final hasTagRecords =
        recordsToCheck.any((r) => r?.tags.isNotEmpty ?? false);
    final uniqueTags =
        recordsToCheck.expand<String>((r) => r?.tags ?? <String>[]).toSet();
    final tagCount = uniqueTags.length;

    final walletsEnabled = ServiceConfig.walletsEnabled;
    final hasWalletRecords = recordsToCheck.any((r) => r?.walletId != null);
    final uniqueWalletIds = recordsToCheck
        .where((r) => r?.walletId != null)
        .map<int>((r) => r!.walletId!)
        .toSet();
    final walletCount = uniqueWalletIds.length;

    final tokens = <Widget>[];
    final isDetailView =
        showRecordsToggle && (hideCategorySelection || hideTagsSelection);

    void addSeparator() {
      if (tokens.isNotEmpty) {
        tokens.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child:
                Text("/", style: TextStyle(fontSize: 18, color: Colors.grey)),
          ),
        );
      }
    }

    void addRecordsToggle() {
      addSeparator();
      tokens.add(_buildToggle(
        label: "Records".i18n,
        isSelected: groupByType == GroupByType.records,
        onTap: () => onGroupByTypeChanged(GroupByType.records),
      ));
    }

    void addCategoriesToggle() {
      addSeparator();
      tokens.add(_buildToggle(
        label: "Categories".i18n,
        isSelected: groupByType == GroupByType.category,
        onTap: () => onGroupByTypeChanged(GroupByType.category),
      ));
    }

    void addTagsToggle() {
      addSeparator();
      tokens.add(_buildTagToggles(
        tagCount: tagCount,
        isSelected: groupByType == GroupByType.tag,
        hasTagRecords: hasTagRecords,
        context: context,
      ));
    }

    void addWalletsToggle() {
      if (!walletsEnabled) return;
      addSeparator();
      tokens.add(_buildWalletToggles(
        walletCount: walletCount,
        isSelected: groupByType == GroupByType.wallet,
        hasWalletRecords: hasWalletRecords,
        context: context,
      ));
    }

    // Determine token order based on view type
    if (isDetailView) {
      if (showRecordsToggle) addRecordsToggle();
      if (!hideCategorySelection) addCategoriesToggle();
      if (!hideTagsSelection) addTagsToggle();
      if (!hideWalletsSelection) addWalletsToggle();
    } else {
      if (!hideCategorySelection) addCategoriesToggle();
      if (!hideTagsSelection) addTagsToggle();
      if (!hideWalletsSelection) addWalletsToggle();
      if (showRecordsToggle) addRecordsToggle();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Wrap(
        spacing: 0,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: tokens,
      ),
    );
  }

  /// Filters records based on current selection state.
  List<Record?> _getFilteredRecords() {
    switch (groupByType) {
      case GroupByType.tag:
        return RecordFilters.byMultipleCriteria(
          records,
          date: selectedDate,
          aggregationMethod: aggregationMethod,
          tag: selectedCategoryOrTag,
          topCategories: topCategories,
        );
      case GroupByType.wallet:
        return RecordFilters.byMultipleCriteria(
          records,
          date: selectedDate,
          aggregationMethod: aggregationMethod,
          walletId: selectedCategoryOrTag,
          topCategories: topCategories,
        );
      case GroupByType.category:
      case GroupByType.records:
        return RecordFilters.byMultipleCriteria(
          records,
          date: selectedDate,
          aggregationMethod: aggregationMethod,
          category: selectedCategoryOrTag,
          topCategories: topCategories,
        );
    }
  }

  /// Builds a clickable token for a grouping option.
  Widget _buildToggle({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? null : Colors.grey,
        ),
      ),
    );
  }

  /// Builds the tag token with special handling for when no tags exist.
  Widget _buildTagToggles({
    required int tagCount,
    required bool isSelected,
    required bool hasTagRecords,
    required BuildContext context,
  }) {
    final label = tagCount > 0
        ? "Tags (%d)".i18n.fill([tagCount])
        : "Tags (%d)".i18n.fill([0]);

    return InkWell(
      onTap: () {
        if (!hasTagRecords) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("No tags found".i18n),
            duration: Duration(seconds: 2),
          ));
          return;
        }
        onGroupByTypeChanged(GroupByType.tag);
      },
      child: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? null : Colors.grey,
        ),
      ),
    );
  }

  /// Builds the wallet token with special handling for when no wallets exist.
  Widget _buildWalletToggles({
    required int walletCount,
    required bool isSelected,
    required bool hasWalletRecords,
    required BuildContext context,
  }) {
    final label = walletCount > 0
        ? "Wallets (%d)".i18n.fill([walletCount])
        : "Wallets (%d)".i18n.fill([0]);

    return InkWell(
      onTap: () {
        if (!hasWalletRecords) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("No wallets found".i18n),
            duration: Duration(seconds: 2),
          ));
          return;
        }
        onGroupByTypeChanged(GroupByType.wallet);
      },
      child: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? null : Colors.grey,
        ),
      ),
    );
  }
}
