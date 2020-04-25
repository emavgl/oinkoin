This package contains translations for strings of widgets (pub.dev/packages/i18n_extension).

The 'i18n_extension' package automatically recognizes the locale of the device and sets
the proper translations

When you are ready to create translations, you must create a dart file to hold them.
This file can have any name, but I suggest you give it the same name as your widget
and change the termination to .i18n.dart.
For example, if your widget is in file 'my_widget.dart', the translations could be
in file 'my_widget.i18n.dart'.

If the translation is not found, the original text is kept