import 'package:flutter/material.dart';
import 'package:piggybank/components/icon_color_picker_section.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/transfer-icon-service.dart';
import 'package:piggybank/style.dart';

class CustomizeTransferIconPage extends StatefulWidget {
  const CustomizeTransferIconPage({Key? key}) : super(key: key);

  @override
  State<CustomizeTransferIconPage> createState() =>
      _CustomizeTransferIconPageState();
}

class _CustomizeTransferIconPageState
    extends State<CustomizeTransferIconPage> {
  late String? _iconEmoji;
  late IconData? _icon;
  late Color? _color;
  int _pickerResetCounter = 0;

  @override
  void initState() {
    super.initState();
    _iconEmoji = TransferIconService.iconEmoji;
    _icon = TransferIconService.icon;
    _color = TransferIconService.color;
  }

  Widget _getPageSeparatorLabel(String labelText) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(15, 15, 0, 5),
        child: Text(
          labelText,
          style: TextStyle(
            fontFamily: FontNameDefault,
            fontWeight: FontWeight.w300,
            fontSize: 26.0,
            color: MaterialThemeInstance.currentTheme?.colorScheme.onSurface,
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  Widget _getTransferCirclePreview() {
    return Container(
      margin: const EdgeInsets.all(10),
      child: ClipOval(
        child: Material(
          color: _color ?? Theme.of(context).colorScheme.surface,
          child: SizedBox(
            width: 70,
            height: 70,
            child: _iconEmoji != null
                ? Center(
                    child: Text(
                      _iconEmoji!,
                      style: const TextStyle(fontSize: 30),
                    ),
                  )
                : Icon(
                    _icon,
                    color: _color != null
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    size: 30,
                  ),
          ),
        ),
      ),
    );
  }

  AppBar _getAppBar() {
    return AppBar(
      title: Text("Customize Transfer Icon".i18n),
      leading: BackButton(onPressed: () => Navigator.pop(context)),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10.0))),
          onSelected: (value) async {
            if (value == 'restore') {
              await _restoreOriginal();
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem<String>(
              padding: const EdgeInsets.all(20),
              value: 'restore',
              child: Text(
                "Restore original transfer icon".i18n,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _restoreOriginal() async {
    await TransferIconService.reset();
    if (!mounted) return;
    setState(() {
      _iconEmoji = TransferIconService.iconEmoji;
      _icon = TransferIconService.icon;
      _color = TransferIconService.color;
      _pickerResetCounter++;
    });
  }

  Future<void> _save() async {
    await TransferIconService.save(
      iconEmoji: _iconEmoji,
      icon: _icon,
      color: _color,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _getAppBar(),
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _getPageSeparatorLabel("Name".i18n),
            const Divider(thickness: 0.5),
            Row(
              children: [
                _getTransferCirclePreview(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      "Transfer".i18n,
                      style: TextStyle(
                        fontSize: 22.0,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            IconColorPickerSection(
              key: ValueKey(_pickerResetCounter),
              initialIconEmoji: _iconEmoji,
              initialIcon: _icon,
              initialColor: _color,
              onChange: (iconEmoji, icon, iconCodePoint, color) {
                setState(() {
                  _iconEmoji = iconEmoji;
                  _icon = icon;
                  _color = color;
                });
              },
            ),
            const SizedBox(height: 75),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _save,
        tooltip: "Save".i18n,
        child: const Icon(Icons.save),
      ),
    );
  }
}
