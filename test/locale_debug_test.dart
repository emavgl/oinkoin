import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:i18n_extension/i18n_extension.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('en_US', null);
  });

  test('check locale', () {
    print('I18n.locale: ${I18n.locale}');
    print('I18n.locale toString: ${I18n.locale.toString()}');
  });
}
