import 'package:flutter/material.dart';
import 'package:piggybank/components/tag_chip.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/category.dart';

class FilterModalContent extends StatefulWidget {
  final List<Category?> categories;
  final List<String> tags;
  final Function(List<Category?> selectedCategories, List<String> selectedTags,
      bool categoryTagORLogic, bool tagORLogic) onApplyFilters;

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

class _FilterModalContentState extends State<FilterModalContent>
    with TickerProviderStateMixin {
  Set<Category?> _categoriesToShow = {};
  Set<String> _tagsToShow = {};

  List<Category?> _selectedCategories = [];
  List<String> _selectedTags = [];

  bool _categoryTagORLogic = true; // true = OR, false = AND
  bool _tagORLogic = false;

  late AnimationController _scrollIndicatorController;
  late Animation<double> _scrollIndicatorAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = false;

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

    _scrollIndicatorController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scrollIndicatorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _scrollIndicatorController, curve: Curves.easeInOut),
    );

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onScroll();
    });
  }

  @override
  void dispose() {
    _scrollIndicatorController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final isAtBottom = _scrollController.offset >=
        _scrollController.position.maxScrollExtent - 50;
    final hasScrollableContent = _scrollController.position.maxScrollExtent > 0;

    final shouldShow = !isAtBottom && hasScrollableContent;

    if (shouldShow != _showScrollIndicator) {
      setState(() {
        _showScrollIndicator = shouldShow;
      });

      if (shouldShow) {
        _scrollIndicatorController.forward();
      } else {
        _scrollIndicatorController.reverse();
      }
    }
  }

  void _onApplyFilters() {
    widget.onApplyFilters(
        _selectedCategories, _selectedTags, _categoryTagORLogic, _tagORLogic);
    Navigator.pop(context);
  }

  void _onClearAllFilters() {
    widget.onApplyFilters([], [], true, false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(16.0),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.67,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filters'.i18n,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Categories Section
                        Text(
                          'Filter by Categories'.i18n,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Limit records by categories'.i18n,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          children: _categoriesToShow.map((category) {
                            bool isSelected =
                                _selectedCategories.contains(category);
                            return TagChip(
                              labelText: category?.name ?? '',
                              isSelected: isSelected,
                              selectedColor: Colors.blue.withValues(alpha: 0.3),
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          _tagORLogic
                              ? 'Show records that have any of the selected tags'
                                  .i18n
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
                          children: _tagsToShow.map((tag) {
                            bool isSelected = _selectedTags.contains(tag);
                            return TagChip(
                              labelText: tag,
                              isSelected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedTags.add(tag);
                                  } else {
                                    _selectedTags.remove(tag);
                                  }
                                });
                              },
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.5),
                              selectedColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.4),
                            );
                          }).toList(),
                        ),

                        SizedBox(height: 20.0),

                        // Categories vs Tags Logic Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Categories vs Tags'.i18n,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                Text('AND',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                Switch(
                                  value: _categoryTagORLogic,
                                  onChanged: (value) {
                                    setState(() {
                                      _categoryTagORLogic = value;
                                    });
                                  },
                                  activeColor: Colors.green,
                                ),
                                Text('OR',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          _categoryTagORLogic
                              ? 'Records matching categories OR tags'.i18n
                              : 'Records must match categories AND tags'.i18n,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                        if (_selectedCategories.isNotEmpty ||
                            _selectedTags.isNotEmpty) ...[
                          SizedBox(height: 16.0),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.grey.withOpacity(0.3)),
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
              ),
              SizedBox(height: 16.0),
              Row(
                children: [
                  if (_selectedCategories.isNotEmpty ||
                      _selectedTags.isNotEmpty) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _onClearAllFilters,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                        ),
                        child: Text(
                          'Clear All Filters'.i18n,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onApplyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Apply Filters'.i18n,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Scroll indicator
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _scrollIndicatorAnimation,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      SizedBox(width: 4),
                      Text(
                        "Scroll for more".i18n,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogicExplanation() {
    List<String> parts = [];

    if (_selectedCategories.isNotEmpty) {
      String categories =
          _selectedCategories.map((c) => '**${c?.name ?? ''}**').join(' OR ');
      parts.add('($categories)');
    }

    if (_selectedTags.isNotEmpty) {
      String connector = _tagORLogic ? ' OR ' : ' AND ';
      String tags = _selectedTags.map((tag) => '**$tag**').join(connector);
      parts.add('($tags)');
    }

    String explanation = '';
    if (parts.length == 2) {
      String connector = _categoryTagORLogic ? ' OR ' : ' AND ';
      explanation = parts.join(connector);
    } else if (parts.length == 1) {
      explanation = parts.first;
    }

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
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(fontWeight: FontWeight.bold),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return spans;
  }
}
