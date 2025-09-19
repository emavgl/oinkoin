import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';

class TagsPageView extends StatefulWidget {
  @override
  TagsPageViewState createState() => TagsPageViewState();
}

class TagsPageViewState extends State<TagsPageView> {
  Set<String>? tags;
  Set<String> selectedTags = <String>{};
  bool isSelectionMode = false;
  DatabaseInterface database = ServiceConfig.database;

  @override
  void initState() {
    super.initState();
    fetchTagsFromDatabase();
  }

  fetchTagsFromDatabase() async {
    var tagSet = await database.getAllTags();
    setState(() {
      tags = tagSet;
    });
  }

  void _toggleSelection(String tag) {
    setState(() {
      if (selectedTags.contains(tag)) {
        selectedTags.remove(tag);
        if (selectedTags.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedTags.add(tag);
        isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      selectedTags.clear();
      isSelectionMode = false;
    });
  }

  void _editSelectedTag() {
    if (selectedTags.length == 1) {
      String tagToEdit = selectedTags.first;
      _showEditTagDialog(tagToEdit);
    }
  }

  void _deleteSelectedTags() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Tags'.i18n),
          content: Text(selectedTags.length == 1
              ? 'Are you sure you want to delete this tag?'.i18n
              : 'Are you sure you want to delete these ${selectedTags.length} tags?'
                  .i18n),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'.i18n),
            ),
            TextButton(
              onPressed: () {
                _performDelete();
                Navigator.of(context).pop();
              },
              child: Text('Delete'.i18n),
            ),
          ],
        );
      },
    );
  }

  void _performDelete() async {
    for (String tag in selectedTags) {
      await database.deleteTag(tag);
    }
    await fetchTagsFromDatabase();
    _clearSelection();
  }

  void _showEditTagDialog(String currentTag) {
    TextEditingController controller = TextEditingController(text: currentTag);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Tag'.i18n),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Tag name'.i18n,
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'.i18n),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty &&
                    controller.text.trim() != currentTag) {
                  _performEdit(currentTag, controller.text.trim());
                }
                Navigator.of(context).pop();
              },
              child: Text('Save'.i18n),
            ),
          ],
        );
      },
    );
  }

  void _performEdit(String oldTag, String newTag) async {
    await database.renameTag(oldTag, newTag);
    await fetchTagsFromDatabase();
    _clearSelection();
  }

  final _biggerFont = const TextStyle(fontSize: 18.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: buildTagsList(),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: Text('Tags'.i18n),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      title: Text('${selectedTags.length} selected'.i18n),
      leading: IconButton(
        icon: Icon(Icons.close),
        onPressed: _clearSelection,
      ),
      actions: [
        if (selectedTags.length == 1)
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _editSelectedTag,
            tooltip: 'Edit tag'.i18n,
          ),
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: _deleteSelectedTags,
          tooltip: 'Delete tags'.i18n,
        ),
      ],
    );
  }

  Widget buildTagsList() {
    if (tags == null) {
      return Center(child: CircularProgressIndicator());
    }

    if (tags!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.label_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No tags found'.i18n,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    List<String> sortedTags = tags!.toList()..sort();

    return ListView.builder(
      itemCount: sortedTags.length,
      itemBuilder: (context, index) {
        String tag = sortedTags[index];
        bool isSelected = selectedTags.contains(tag);

        return Container(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : null,
          child: ListTile(
            leading: isSelectionMode
                ? Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                  )
                : Icon(
                    Icons.label,
                    color: Theme.of(context).primaryColor,
                  ),
            title: Text(
              tag,
              style: _biggerFont,
            ),
            selected: isSelected,
            onTap: () {
              if (isSelectionMode) {
                _toggleSelection(tag);
              }
            },
            onLongPress: () {
              _toggleSelection(tag);
            },
          ),
        );
      },
    );
  }
}
