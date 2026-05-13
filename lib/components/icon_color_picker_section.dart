import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emojipicker;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:piggybank/models/category-icons.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/style.dart';

import '../i18n.dart';

/// Shared icon + color picker used by EditCategoryPage and EditWalletPage.
///
/// Displays a grid of FontAwesome icons (with an emoji option at the front) and
/// a horizontal color palette. Calls [onChange] whenever the user makes a
/// selection, passing back the full current icon/emoji/color state.
class IconColorPickerSection extends StatefulWidget {
  final String? initialIconEmoji;
  final IconData? initialIcon;
  final Color? initialColor;

  /// The palette to display. Defaults to [Category.colors] when null.
  final List<Color?> colors;

  /// Called whenever the user changes icon or color.
  /// Always receives the complete current selection.
  final void Function(
    String? iconEmoji,
    IconData? icon,
    int? iconCodePoint,
    Color? color,
  ) onChange;

  const IconColorPickerSection({
    Key? key,
    this.initialIconEmoji,
    this.initialIcon,
    this.initialColor,
    List<Color?>? colors,
    required this.onChange,
  })  : colors = colors ?? const [],
        super(key: key);

  @override
  _IconColorPickerSectionState createState() => _IconColorPickerSectionState();
}

class _IconColorPickerSectionState extends State<IconColorPickerSection> {
  late List<IconData?> _icons;
  late int? _chosenColorIndex;
  late int? _chosenIconIndex;
  late Color? _pickedColor;
  late String _currentEmoji;
  bool _emojiShowing = false;
  final TextEditingController _emojiController = TextEditingController();
  final ScrollController _colorScrollController = ScrollController();

  // Current tracked selection
  IconData? _currentIcon;
  int? _currentIconCodePoint;
  String? _currentIconEmoji;
  Color? _currentColor;

  List<Color?> get _palette =>
      widget.colors.isNotEmpty ? widget.colors : Category.colors;

  @override
  void initState() {
    super.initState();
    _icons = ServiceConfig.isPremium
        ? CategoryIcons.pro_category_icons
        : CategoryIcons.free_category_icons;

    _currentEmoji = widget.initialIconEmoji ?? '😎';

    if (widget.initialIconEmoji != null) {
      _chosenIconIndex = -1;
      _currentIconEmoji = widget.initialIconEmoji;
      _currentIcon = null;
      _currentIconCodePoint = null;
    } else {
      _chosenIconIndex = _icons.indexOf(widget.initialIcon);
      _currentIcon = widget.initialIcon;
      _currentIconCodePoint = widget.initialIcon?.codePoint;
      _currentIconEmoji = null;
    }

    _currentColor = widget.initialColor;
    _chosenColorIndex = _palette.indexOf(widget.initialColor);
    if (_chosenColorIndex == -1 && widget.initialColor != null) {
      _pickedColor = widget.initialColor;
    } else {
      _pickedColor = null;
    }
  }

  void _notifyChange() {
    widget.onChange(
      _currentIconEmoji,
      _currentIcon,
      _currentIconCodePoint,
      _currentColor,
    );
  }

  @override
  void dispose() {
    _emojiController.dispose();
    _colorScrollController.dispose();
    super.dispose();
  }

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Container(
            padding: EdgeInsets.all(15),
            color: Theme.of(context).primaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Choose a color".i18n,
                    style: TextStyle(color: Colors.white)),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.white,
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop('dialog'),
                ),
              ],
            ),
          ),
          titlePadding: const EdgeInsets.all(0.0),
          contentPadding: const EdgeInsets.all(0.0),
          content: SingleChildScrollView(
            child: MaterialPicker(
              pickerColor: _palette[0] ?? Colors.blue,
              onColorChanged: (newColor) {
                setState(() {
                  _pickedColor = newColor;
                  _chosenColorIndex = -1;
                  _currentColor = newColor;
                });
                _notifyChange();
              },
              enableLabel: false,
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorList() {
    return ListView.builder(
      shrinkWrap: true,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _palette.length,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.all(10),
          child: SizedBox(
            width: 70,
            child: ClipOval(
              child: Material(
                color: _palette[index],
                child: InkWell(
                  splashColor: Colors.white30,
                  child: (index == _chosenColorIndex)
                      ? SizedBox(
                          width: 50,
                          height: 50,
                          child:
                              Icon(Icons.check, color: Colors.white, size: 20),
                        )
                      : Container(),
                  onTap: () {
                    setState(() {
                      _chosenColorIndex = index;
                      _pickedColor = null;
                      _currentColor = _palette[index];
                    });
                    _notifyChange();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _createNoColorCircle() {
    return Container(
      margin: EdgeInsets.all(10),
      child: Stack(
        children: [
          ClipOval(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                      width: 2.0,
                    ),
                  ),
                  child: Icon(Icons.not_interested,
                      color: Theme.of(context).colorScheme.onSurface, size: 30),
                ),
                onTap: () {
                  setState(() {
                    _pickedColor = null;
                    _chosenColorIndex = -2;
                    _currentColor = null;
                  });
                  _notifyChange();
                },
              ),
            ),
          ),
          ServiceConfig.isPremium ? Container() : getProLabel(),
        ],
      ),
    );
  }

  Widget _createColorPickerCircle() {
    return Container(
      margin: EdgeInsets.all(10),
      child: Stack(
        children: [
          ClipOval(
            child: Material(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: _pickedColor == null
                        ? [Colors.yellow, Colors.red, Colors.indigo, Colors.teal]
                        : [_pickedColor!, _pickedColor!],
                  ),
                ),
                child: InkWell(
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child:
                        Icon(Icons.colorize, color: Colors.white, size: 30),
                  ),
                  onTap: ServiceConfig.isPremium
                      ? _openColorPicker
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PremiumSplashScreen()),
                          );
                        },
                ),
              ),
            ),
          ),
          ServiceConfig.isPremium ? Container() : getProLabel(),
        ],
      ),
    );
  }

  Widget _createColorsList() {
    return Scrollbar(
      controller: _colorScrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: SingleChildScrollView(
          controller: _colorScrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: 90,
            child: Row(
              children: [
                _createNoColorCircle(),
                _createColorPickerCircle(),
                _buildColorList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getIconsGrid() {
    var surfaceContainer = Theme.of(context).colorScheme.surfaceContainer;
    var bottomActionColor = Theme.of(context).colorScheme.surfaceContainerLow;
    var buttonColors =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      children: [
        Offstage(
          offstage: !_emojiShowing,
          child: emojipicker.EmojiPicker(
            textEditingController: _emojiController,
            config: emojipicker.Config(
              locale: I18n.locale,
              height: 256,
              checkPlatformCompatibility: true,
              emojiViewConfig: emojipicker.EmojiViewConfig(
                  emojiSizeMax: 28, backgroundColor: surfaceContainer),
              categoryViewConfig: emojipicker.CategoryViewConfig(
                backgroundColor: bottomActionColor,
                iconColorSelected: buttonColors,
              ),
              bottomActionBarConfig: emojipicker.BottomActionBarConfig(
                backgroundColor: bottomActionColor,
                buttonColor: buttonColors,
                showBackspaceButton: false,
              ),
              searchViewConfig: emojipicker.SearchViewConfig(
                backgroundColor: Colors.white,
              ),
            ),
            onEmojiSelected: (c, emoji) {
              setState(() {
                _emojiShowing = false;
                _emojiController.text = emoji.emoji;
                _chosenIconIndex = -1;
                _currentEmoji = emoji.emoji;
                _currentIconEmoji = emoji.emoji;
                _currentIcon = null;
                _currentIconCodePoint = null;
              });
              _notifyChange();
            },
          ),
        ),
        GridView.count(
          padding: EdgeInsets.all(0),
          crossAxisCount: 5,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: [
            Container(
              alignment: Alignment.center,
              child: IconButton(
                icon: ServiceConfig.isPremium
                    ? Text(_currentEmoji, style: TextStyle(fontSize: 24))
                    : Stack(children: [
                        Text(_currentEmoji, style: TextStyle(fontSize: 24)),
                        if (!ServiceConfig.isPremium)
                          Container(
                            margin: EdgeInsets.fromLTRB(20, 20, 0, 0),
                            child: getProLabel(labelFontSize: 10.0),
                          ),
                      ]),
                onPressed: ServiceConfig.isPremium
                    ? () => setState(() => _emojiShowing = !_emojiShowing)
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PremiumSplashScreen()),
                        );
                      },
              ),
            ),
            ...List.generate(_icons.length, (index) {
              return IconButton(
                icon: FaIcon(_icons[index]),
                color: (_chosenIconIndex == index)
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                onPressed: () {
                  setState(() {
                    _emojiShowing = false;
                    _chosenIconIndex = index;
                    _currentIcon = _icons[index];
                    _currentIconCodePoint = _icons[index]?.codePoint;
                    _currentIconEmoji = null;
                  });
                  _notifyChange();
                },
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildExpansionTile(String title, Widget content) {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.fromLTRB(15, 0, 15, 0),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: FontNameDefault,
          fontWeight: FontWeight.w300,
          fontSize: 26.0,
          color: MaterialThemeInstance.currentTheme?.colorScheme.onSurface,
        ),
      ),
      children: [
        Divider(thickness: 0.5),
        content,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildExpansionTile("Color".i18n, _createColorsList()),
        _buildExpansionTile("Icon".i18n, _getIconsGrid()),
      ],
    );
  }
}
