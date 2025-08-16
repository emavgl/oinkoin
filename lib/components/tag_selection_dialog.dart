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

class _TagSelectionDialogState extends State<TagSelectionDialog> {
  DatabaseInterface database = ServiceConfig.database;
  TextEditingController _searchController = TextEditingController();
  List<String> _allTags = [];
  List<String> _filteredTags = [];
  List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialSelectedTags);
    _loadAllTags();
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text("Select Tags".i18n),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _selectedTags),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern search bar with rounded shape + add button
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TypeAheadField<String>(
                      controller: _searchController,
                      builder: (context, controller, focusNode) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: "Search or add tag".i18n,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _filterTags('');
                              },
                            ),
                          ),
                          onChanged: _filterTags,
                          onSubmitted: _addTagFromInput,
                        );
                      },
                      suggestionsCallback: (pattern) async {
                        if (pattern.isEmpty) return [];
                        return _allTags
                            .where((tag) => tag
                                .toLowerCase()
                                .contains(pattern.toLowerCase()))
                            .toList();
                      },
                      itemBuilder: (context, suggestion) {
                        return ListTile(title: Text(suggestion));
                      },
                      onSelected: (suggestion) {
                        _toggleTagSelection(suggestion);
                        _searchController.clear();
                        _filterTags('');
                      },
                    ),
                  ),
                ),
                SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(14),
                  ),
                  onPressed: () =>
                      _addTagFromInput(_searchController.text.trim()),
                  child: Icon(Icons.keyboard_return),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Selected tags section
            if (_selectedTags.isNotEmpty) ...[
              Text(
                "Selected Tags".i18n,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 6.0,
                children: _selectedTags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    deleteIcon: Icon(Icons.close, size: 18),
                    onDeleted: () => _toggleTagSelection(tag),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
            ],

            // Remaining tags
            Text(
              "All Tags".i18n,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _filteredTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (_) => _toggleTagSelection(tag),
                      selectedColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      checkmarkColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addTagFromInput(String value) {
    // Trim spaces
    final tag = value.trim();

    // Validate: only a single word, no commas allowed
    final isValid = RegExp(r'^[^\s,]+$').hasMatch(tag);

    if (tag.isEmpty || !isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Tags must be a single word without commas.".i18n)),
      );
      return;
    }

    if (!_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _allTags.add(tag);
        _searchController.clear();
        _filterTags('');
      });
    }
  }
}
