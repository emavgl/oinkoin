import 'package:flutter/material.dart';
import 'package:piggybank/components/tag_chip.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/category.dart';

import '../../models/category-type.dart';

class FilterModalContent extends StatefulWidget {
  final List<Category?> categories;
  final List<String> tags;
  final Function(
    List<Category?> selectedCategories,
    List<String> selectedTags,
    bool categoryTagORLogic,
    bool tagORLogic,
  )
  onApplyFilters;

  final List<Category?> currentlySelectedCategories;
  final List<String> currentlySelectedTags;
  final bool currentCategoryTagOrLogic;
  final bool currentTagsOrLogic;

  const FilterModalContent({
    Key? key,
    required this.categories,
    required this.tags,
    required this.onApplyFilters,
    required this.currentlySelectedCategories,
    required this.currentlySelectedTags,
    required this.currentCategoryTagOrLogic,
    required this.currentTagsOrLogic,
  }) : super(key: key);

  @override
  State<FilterModalContent> createState() => _FilterModalContentState();
}

class _FilterModalContentState extends State<FilterModalContent> {
  Set<Category?> _categoriesToShow = {};
  Set<String> _tagsToShow = {};

  List<Category?> _selectedCategories = [];
  List<String> _selectedTags = [];

  bool _categoryTagORLogic = true;
  bool _tagORLogic = false;

  final ScrollController _scrollController = ScrollController();
  bool _categoriesExpanded = true;
  bool _tagsExpanded = false;
  bool _logicExpanded = false;

  @override
  void initState() {
    super.initState();

    _categoriesToShow = widget.categories.toSet();
    _categoriesToShow.addAll(widget.currentlySelectedCategories);

    _tagsToShow = widget.tags.toSet();
    _tagsToShow.addAll(widget.currentlySelectedTags);

    _selectedCategories = List.from(widget.currentlySelectedCategories);
    _selectedTags = List.from(widget.currentlySelectedTags);

    _categoryTagORLogic = widget.currentCategoryTagOrLogic;
    _tagORLogic = widget.currentTagsOrLogic;
    _tagsExpanded = _selectedTags.isNotEmpty;
    _logicExpanded = _selectedCategories.isNotEmpty && _selectedTags.isNotEmpty;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasSelections =>
      _selectedCategories.isNotEmpty || _selectedTags.isNotEmpty;

  void _onApplyFilters() {
    widget.onApplyFilters(
      _selectedCategories,
      _selectedTags,
      _categoryTagORLogic,
      _tagORLogic,
    );
    Navigator.pop(context);
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategories = [];
      _selectedTags = [];
      _categoryTagORLogic = true;
      _tagORLogic = false;
      _categoriesExpanded = true;
      _tagsExpanded = false;
      _logicExpanded = false;
    });
  }

  List<Category?> _getCategoriesByType(CategoryType? type) {
    return _categoriesToShow
        .where((category) => category?.categoryType == type)
        .toList();
  }

  void _toggleCategory(Category? category, bool selected) {
    setState(() {
      if (selected) {
        _selectedCategories.add(category);
      } else {
        _selectedCategories.remove(category);
      }
      if (_selectedCategories.isNotEmpty && _selectedTags.isNotEmpty) {
        _logicExpanded = true;
      }
    });
  }

  void _toggleTag(String tag, bool selected) {
    setState(() {
      if (selected) {
        _selectedTags.add(tag);
      } else {
        _selectedTags.remove(tag);
      }
      if (_selectedCategories.isNotEmpty && _selectedTags.isNotEmpty) {
        _logicExpanded = true;
      }
    });
  }

  bool _allCategoriesSelected(List<Category?> categories) {
    return categories.isNotEmpty &&
        categories.every(_selectedCategories.contains);
  }

  bool get _allTagsSelected =>
      _tagsToShow.isNotEmpty && _tagsToShow.every(_selectedTags.contains);

  void _toggleAllCategories(List<Category?> categories) {
    setState(() {
      if (_allCategoriesSelected(categories)) {
        _selectedCategories.removeWhere(categories.contains);
      } else {
        _selectedCategories = {..._selectedCategories, ...categories}.toList();
      }
      if (_selectedTags.isNotEmpty) {
        _logicExpanded = true;
      }
    });
  }

  void _toggleAllTags() {
    setState(() {
      if (_allTagsSelected) {
        _selectedTags = [];
        _logicExpanded = false;
      } else {
        _selectedTags = _tagsToShow.toList();
        _logicExpanded = true;
      }
    });
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required bool expanded,
    required VoidCallback onTap,
    VoidCallback? onToggleAll,
    bool allSelected = false,
    int count = 0,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onToggleAll != null)
                IconButton(
                  onPressed: onToggleAll,
                  tooltip: 'Select all'.i18n,
                  icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                  visualDensity: VisualDensity.compact,
                ),
              if (count > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(List<Category?> categories, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: categories.map((category) {
          return TagChip(
            labelText: category?.name ?? '',
            isSelected: _selectedCategories.contains(category),
            selectedColor: color.withValues(alpha: 0.2),
            onSelected: (selected) => _toggleCategory(category, selected),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryGroup({
    required String title,
    required List<Category?> categories,
    required Color color,
    required IconData icon,
  }) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _toggleAllCategories(categories),
              tooltip: 'Select all'.i18n,
              icon: Icon(
                _allCategoriesSelected(categories)
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCategoryChips(categories, color),
      ],
    );
  }

  Widget _buildCategoryOptions(
    List<Category?> expenseCategories,
    List<Category?> incomeCategories,
  ) {
    if (expenseCategories.isEmpty && incomeCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasBothTypes =
        expenseCategories.isNotEmpty && incomeCategories.isNotEmpty;
    if (!hasBothTypes) {
      final isExpense = expenseCategories.isNotEmpty;
      return _buildCategoryGroup(
        title: (isExpense ? 'Expense Categories' : 'Income Categories').i18n,
        categories: isExpense ? expenseCategories : incomeCategories,
        color: isExpense ? Colors.red[600]! : Colors.green[600]!,
        icon: isExpense
            ? Icons.remove_circle_outline
            : Icons.add_circle_outline,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryGroup(
          title: 'Expense Categories'.i18n,
          categories: expenseCategories,
          color: Colors.red[600]!,
          icon: Icons.remove_circle_outline,
        ),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        _buildCategoryGroup(
          title: 'Income Categories'.i18n,
          categories: incomeCategories,
          color: Colors.green[600]!,
          icon: Icons.add_circle_outline,
        ),
      ],
    );
  }

  Widget _buildTagOptions() {
    if (_tagsToShow.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          'No tags found'.i18n,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: _tagsToShow.map((tag) {
          return TagChip(
            labelText: tag,
            isSelected: _selectedTags.contains(tag),
            onSelected: (selected) => _toggleTag(tag, selected),
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            selectedColor: Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: 0.4),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogicToggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          ToggleButtons(
            isSelected: [!value, value],
            onPressed: (index) => onChanged(index == 1),
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
            children: const [Text('AND'), Text('OR')],
          ),
        ],
      ),
    );
  }

  Widget _buildLogicOptions() {
    if (_selectedTags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogicToggle(
            title: 'Filter by Tags'.i18n,
            value: _tagORLogic,
            onChanged: (value) => setState(() => _tagORLogic = value),
          ),
          if (_selectedCategories.isNotEmpty)
            _buildLogicToggle(
              title: 'Categories vs Tags'.i18n,
              value: _categoryTagORLogic,
              onChanged: (value) => setState(() => _categoryTagORLogic = value),
            ),
          _buildLogicExplanation(),
        ],
      ),
    );
  }

  Widget _buildLogicExplanation() {
    final parts = <String>[];

    if (_selectedCategories.isNotEmpty) {
      final categories = _selectedCategories
          .map((category) => '**${category?.name ?? ''}**')
          .join(' OR ');
      parts.add('($categories)');
    }

    if (_selectedTags.isNotEmpty) {
      final connector = _tagORLogic ? ' OR ' : ' AND ';
      final tags = _selectedTags.map((tag) => '**$tag**').join(connector);
      parts.add('($tags)');
    }

    final explanation = switch (parts.length) {
      2 => parts.join(_categoryTagORLogic ? ' OR ' : ' AND '),
      1 => parts.first,
      _ => '',
    };

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        children: _parseMarkdownText('Showing records matching: $explanation'),
      ),
    );
  }

  List<TextSpan> _parseMarkdownText(String text) {
    final spans = <TextSpan>[];
    final expression = RegExp(r'\*\*(.*?)\*\*');
    var lastMatchEnd = 0;

    for (final match in expression.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final expenseCategories = _getCategoriesByType(CategoryType.expense);
    final incomeCategories = _getCategoriesByType(CategoryType.income);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filters'.i18n,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_hasSelections)
                  IconButton(
                    onPressed: _clearAllFilters,
                    tooltip: 'Clear All Filters'.i18n,
                    icon: const Icon(Icons.restart_alt),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close'.i18n,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  _buildSectionHeader(
                    title: 'Filter by Categories'.i18n,
                    icon: Icons.category_outlined,
                    expanded: _categoriesExpanded,
                    count: _selectedCategories.length,
                    onTap: () => setState(
                      () => _categoriesExpanded = !_categoriesExpanded,
                    ),
                  ),
                  if (_categoriesExpanded)
                    _buildCategoryOptions(expenseCategories, incomeCategories),
                  if (_tagsToShow.isNotEmpty) ...[
                    Divider(color: colorScheme.outlineVariant),
                    _buildSectionHeader(
                      title: 'Filter by Tags'.i18n,
                      icon: Icons.local_offer_outlined,
                      expanded: _tagsExpanded,
                      count: _selectedTags.length,
                      onToggleAll: _toggleAllTags,
                      allSelected: _allTagsSelected,
                      onTap: () =>
                          setState(() => _tagsExpanded = !_tagsExpanded),
                    ),
                    if (_tagsExpanded) _buildTagOptions(),
                    if (_selectedTags.isNotEmpty) ...[
                      Divider(color: colorScheme.outlineVariant),
                      _buildSectionHeader(
                        title: 'Filter Logic'.i18n,
                        icon: Icons.tune,
                        expanded: _logicExpanded,
                        onTap: () =>
                            setState(() => _logicExpanded = !_logicExpanded),
                      ),
                      if (_logicExpanded) _buildLogicOptions(),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onApplyFilters,
                icon: const Icon(Icons.check),
                label: Text('Apply Filters'.i18n, textAlign: TextAlign.center),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
