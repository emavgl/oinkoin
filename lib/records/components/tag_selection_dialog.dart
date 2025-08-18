import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';

class TagSelectionDialog extends StatefulWidget {
  final List<String> initialSelectedTags;

  TagSelectionDialog({Key? key, required this.initialSelectedTags})
      : super(key: key);

  @override
  _TagSelectionDialogState createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<TagSelectionDialog>
    with TickerProviderStateMixin {
  DatabaseInterface database = ServiceConfig.database;
  TextEditingController _searchController = TextEditingController();
  List<String> _allTags = [];
  List<String> _filteredTags = [];
  List<String> _selectedTags = [];
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialSelectedTags);
    _loadAllTags();

    _fabAnimationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    // Animate FAB when there are selected tags
    if (_selectedTags.isNotEmpty) {
      _fabAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTags() async {
    final tags = await database.getAllTags();
    setState(() {
      _allTags = tags;
      _filteredTags = tags;
    });
  }

  void _filterTags(String searchText) {
    setState(() {
      _filteredTags = _allTags
          .where((tag) => tag.toLowerCase().contains(searchText.toLowerCase()))
          .toList();
    });
  }

  void _toggleTagSelection(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }

      // Animate FAB based on selection
      if (_selectedTags.isNotEmpty) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "Add tags".i18n,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context), // Returns null
        ),
      ),
      body: Column(
        children: [
          // Search section with elegant design
          Container(
            margin: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Search or create tags".i18n,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                SizedBox(height: 12),
                _buildSearchField(colorScheme),
              ],
            ),
          ),

          // Selected tags section with better styling
          if (_selectedTags.isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Selected (${_selectedTags.length})".i18n,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _selectedTags
                        .map((tag) => _buildSelectedChip(tag, colorScheme))
                        .toList(),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],

          // All tags section
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 20,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Available Tags".i18n,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: _filteredTags.isEmpty
                        ? _buildEmptyState(colorScheme, textTheme)
                        : _buildTagsGrid(colorScheme),
                  ),
                ],
              ),
            ),
          ),

          // Bottom padding for FAB
          SizedBox(height: 80),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: FloatingActionButton.extended(
            onPressed: () => Navigator.pop(context, _selectedTags),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 8,
            icon: Icon(Icons.check),
            label: Text(
              "Add selected tags (${_selectedTags.length})".i18n,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: TypeAheadField<String>(
              controller: _searchController,
              emptyBuilder: (context) => SizedBox.shrink(),
              hideOnEmpty: true,
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Search or add new tag...".i18n,
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    prefixIcon: Icon(
                      Icons.search,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 20),
                            color: colorScheme.onSurface.withOpacity(0.5),
                            onPressed: () {
                              _searchController.clear();
                              _filterTags('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _filterTags,
                  onSubmitted: _addTagFromInput,
                );
              },
              suggestionsCallback: (pattern) async {
                if (pattern.isEmpty) return [];
                return _allTags
                    .where((tag) =>
                        tag.toLowerCase().contains(pattern.toLowerCase()))
                    .take(5)
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.label, size: 18, color: colorScheme.primary),
                      SizedBox(width: 12),
                      Text(suggestion),
                    ],
                  ),
                );
              },
              onSelected: (suggestion) {
                _toggleTagSelection(suggestion);
                _searchController.clear();
                _filterTags('');
              },
            ),
          ),
        ),
        SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            onPressed: () => _addTagFromInput(_searchController.text.trim()),
            icon: Icon(Icons.add, color: colorScheme.onPrimary),
            iconSize: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedChip(String tag, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 6),
            GestureDetector(
              onTap: () => _toggleTagSelection(tag),
              child: Icon(
                Icons.close,
                size: 16,
                color: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsGrid(ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _filteredTags.map((tag) {
          final isSelected = _selectedTags.contains(tag);
          return GestureDetector(
            onTap: () => _toggleTagSelection(tag),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outline.withOpacity(0.2),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    Icon(
                      Icons.check,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    SizedBox(width: 6),
                  ],
                  Text(
                    tag,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.label_off_outlined,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          SizedBox(height: 16),
          Text(
            "No tags found".i18n,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Try searching or create a new tag".i18n,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _addTagFromInput(String value) {
    final tag = value.trim();
    final isValid = RegExp(r'^[^\s,]+$').hasMatch(tag);

    if (tag.isEmpty || !isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Tags must be a single word without commas.".i18n),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (!_allTags.contains(tag)) {
      setState(() {
        _allTags.add(tag);
        _filterTags('');
      });
    }

    if (!_selectedTags.contains(tag)) {
      _toggleTagSelection(tag);
    }

    _searchController.clear();
    _filterTags('');
  }
}
