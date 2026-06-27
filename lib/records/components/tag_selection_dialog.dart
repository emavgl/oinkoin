import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:piggybank/components/tag_chip.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';

class TagSelectionDialog extends StatefulWidget {
  final Set<String> initialSelectedTags;

  TagSelectionDialog({Key? key, required this.initialSelectedTags})
      : super(key: key);

  @override
  _TagSelectionDialogState createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<TagSelectionDialog>
    with TickerProviderStateMixin {
  DatabaseInterface database = ServiceConfig.database;
  TextEditingController _searchController = TextEditingController();
  Set<String> _allTags = {};
  Set<String> _filteredTags = {};
  Set<String> _selectedTags = {};
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _selectedTags = Set.from(widget.initialSelectedTags);
    _loadAllTags();

    _fabAnimationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

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
    final tags = (await database.getAllTags())
        .where((tag) => tag.trim().isNotEmpty)
        .toSet();
    setState(() {
      _allTags = tags;
      _filteredTags = tags;
    });
  }

  void _filterTags(String searchText) {
    setState(() {
      _filteredTags = _allTags
          .where((tag) => tag.trim().isNotEmpty)
          .where((tag) => tag.toLowerCase().contains(searchText.toLowerCase()))
          .toSet();
    });
  }

  void _toggleTagSelection(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }

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
      resizeToAvoidBottomInset: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text("Add tags".i18n),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 100), // space for FAB
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search section
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

              // Selected tags
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedTags.map((tag) {
                      return TagChip(
                        labelText: tag,
                        isSelected: true,
                        onSelected: (_) => _toggleTagSelection(tag),
                        selectedColor: colorScheme.primary,
                        textLabelColor: colorScheme.onPrimary,
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 20),
              ],

              // Available tags
              Container(
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
                    _filteredTags.isEmpty
                        ? _buildEmptyState(colorScheme, textTheme)
                        : _buildTagsGrid(colorScheme),
                  ],
                ),
              ),
            ],
          ),
        ),
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
              "Add selected tags (%s)"
                  .i18n
                  .fill([_selectedTags.length.toString()]),
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

  Widget _buildTagsGrid(ColorScheme colorScheme) {
    // Removed SingleChildScrollView here (already inside global scroll)
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _filteredTags.map((tag) {
        return TagChip(
          labelText: tag,
          isSelected: _selectedTags.contains(tag),
          onSelected: (selected) => _toggleTagSelection(tag),
          selectedColor: Theme.of(context).colorScheme.secondaryContainer,
        );
      }).toList(),
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
