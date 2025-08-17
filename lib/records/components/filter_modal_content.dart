import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/category.dart';

class FilterModalContent extends StatefulWidget {
  final List<Category?> categories;
  final List<String> tags;
  final Function(List<Category?> selectedCategories, List<String> selectedTags,
      bool categoryORLogic, bool tagORLogic) onApplyFilters;

  final List<Category?> currentlySelectedCategories;
  final List<String> currentlySelectedTags;

  const FilterModalContent({
    Key? key,
    required this.categories,
    required this.tags,
    required this.onApplyFilters,
    required this.currentlySelectedCategories,
    required this.currentlySelectedTags,
  }) : super(key: key);

  @override
  State<FilterModalContent> createState() => _FilterModalContentState();
}

class _FilterModalContentState extends State<FilterModalContent> {
  List<Category?> _selectedCategories = [];
  List<String> _selectedTags = [];
  bool _categoryORLogic = true; // true = OR, false = AND
  bool _tagORLogic = false; // true = OR, false = AND

  @override
  void initState() {
    super.initState();
    _selectedCategories = widget.currentlySelectedCategories;
    _selectedTags = widget.currentlySelectedTags;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.0),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed header
          Text(
            'Filters'.i18n,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter by Categories'.i18n,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Text('AND',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          Switch(
                            value: _categoryORLogic,
                            onChanged: (value) {
                              setState(() {
                                _categoryORLogic = value;
                              });
                            },
                            activeColor: Colors.blue,
                          ),
                          Text('OR',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    _categoryORLogic
                        ? 'Show records from any selected category'.i18n
                        : 'Show records that match all selected categories'
                            .i18n,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    children: widget.categories.map((category) {
                      bool isSelected = _selectedCategories.contains(category);
                      return FilterChip(
                        label: Text(category?.name ?? ''),
                        selected: isSelected,
                        selectedColor: Colors.blue.withOpacity(0.3),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategories.add(category);
                            } else {
                              _selectedCategories.remove(category);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 20.0),

                  // Tags Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter by Tags'.i18n,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Text('AND',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          Switch(
                            value: _tagORLogic,
                            onChanged: (value) {
                              setState(() {
                                _tagORLogic = value;
                              });
                            },
                            activeColor: Colors.orange,
                          ),
                          Text('OR',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    _tagORLogic
                        ? 'Show records that have any of the selected tags'.i18n
                        : 'Show records that have all selected tags'.i18n,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    children: widget.tags.map((tag) {
                      bool isSelected = _selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        selectedColor: Colors.orange.withOpacity(0.3),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  // Logic Explanation
                  if (_selectedCategories.isNotEmpty ||
                      _selectedTags.isNotEmpty) ...[
                    SizedBox(height: 16.0),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text(
                                'Filter Logic'.i18n,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          _buildLogicExplanation(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Fixed bottom buttons
          SizedBox(height: 16.0),
          Row(
            children: [
              // Clear All Filters Button (only show if filters are selected)
              if (_selectedCategories.isNotEmpty ||
                  _selectedTags.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onApplyFilters([], [], true, false);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                    ),
                    child: Text(
                      'Clear All Filters'.i18n,
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
              ],
              // Apply Filters Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApplyFilters(_selectedCategories, _selectedTags,
                        _categoryORLogic, _tagORLogic);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white),
                  child: Text(
                    'Apply Filters'.i18n,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogicExplanation() {
    List<String> parts = [];

    if (_selectedCategories.isNotEmpty) {
      String connector = _categoryORLogic ? ' OR ' : ' AND ';
      String categories = _selectedCategories
          .map((c) => '**${c?.name ?? ''}**')
          .join(connector);
      parts.add('($categories)');
    }

    if (_selectedTags.isNotEmpty) {
      String connector = _tagORLogic ? ' OR ' : ' AND ';
      String tags = _selectedTags.map((tag) => '**$tag**').join(connector);
      parts.add('($tags)');
    }

    String explanation = parts.join(' **AND** ');

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
        children: _parseMarkdownText('Showing records matching: $explanation'),
      ),
    );
  }

  List<TextSpan> _parseMarkdownText(String text) {
    List<TextSpan> spans = [];
    RegExp exp = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (RegExpMatch match in exp.allMatches(text)) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      // Add bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(fontWeight: FontWeight.bold),
      ));

      lastMatchEnd = match.end;
    }

    // Add remaining text
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return spans;
  }
}
