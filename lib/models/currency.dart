import 'package:intl/intl.dart';

class CurrencyInfo {
  final String isoCode;
  final String name;
  final String? customSymbol;

  const CurrencyInfo(
      {required this.isoCode, required this.name, this.customSymbol});

  String get symbol {
    if (customSymbol != null) return customSymbol!;
    try {
      return NumberFormat.simpleCurrency(name: isoCode).currencySymbol;
    } catch (_) {
      return isoCode;
    }
  }

  static final List<CurrencyInfo> _customCurrencies = [];

  static void addCustomCurrency(CurrencyInfo currency) {
    final existing = _customCurrencies
        .indexWhere((c) => c.isoCode == currency.isoCode.toUpperCase());
    if (existing >= 0) {
      _customCurrencies[existing] = currency;
    } else {
      _customCurrencies.add(CurrencyInfo(
        isoCode: currency.isoCode.toUpperCase(),
        name: currency.name,
        customSymbol: currency.customSymbol,
      ));
    }
  }

  static List<CurrencyInfo> get customCurrencies =>
      List.unmodifiable(_customCurrencies);

  static const List<CurrencyInfo> allCurrencies = [
    CurrencyInfo(isoCode: 'USD', name: 'US Dollar'),
    CurrencyInfo(isoCode: 'EUR', name: 'Euro'),
    CurrencyInfo(isoCode: 'GBP', name: 'British Pound'),
    CurrencyInfo(isoCode: 'JPY', name: 'Japanese Yen'),
    CurrencyInfo(isoCode: 'CHF', name: 'Swiss Franc'),
    CurrencyInfo(isoCode: 'CNY', name: 'Chinese Yuan'),
    CurrencyInfo(isoCode: 'INR', name: 'Indian Rupee'),
    CurrencyInfo(isoCode: 'CAD', name: 'Canadian Dollar'),
    CurrencyInfo(isoCode: 'AUD', name: 'Australian Dollar'),
    CurrencyInfo(isoCode: 'BRL', name: 'Brazilian Real'),
    CurrencyInfo(isoCode: 'KRW', name: 'South Korean Won'),
    CurrencyInfo(isoCode: 'MXN', name: 'Mexican Peso'),
    CurrencyInfo(isoCode: 'NOK', name: 'Norwegian Krone'),
    CurrencyInfo(isoCode: 'SEK', name: 'Swedish Krona'),
    CurrencyInfo(isoCode: 'DKK', name: 'Danish Krone'),
    CurrencyInfo(isoCode: 'PLN', name: 'Polish Zloty'),
    CurrencyInfo(isoCode: 'CZK', name: 'Czech Koruna'),
    CurrencyInfo(isoCode: 'HUF', name: 'Hungarian Forint'),
    CurrencyInfo(isoCode: 'RON', name: 'Romanian Leu'),
    CurrencyInfo(isoCode: 'RUB', name: 'Russian Ruble'),
    CurrencyInfo(isoCode: 'TRY', name: 'Turkish Lira'),
    CurrencyInfo(isoCode: 'ILS', name: 'Israeli Shekel'),
    CurrencyInfo(isoCode: 'SAR', name: 'Saudi Riyal'),
    CurrencyInfo(isoCode: 'AED', name: 'UAE Dirham'),
    CurrencyInfo(isoCode: 'THB', name: 'Thai Baht'),
    CurrencyInfo(isoCode: 'SGD', name: 'Singapore Dollar'),
    CurrencyInfo(isoCode: 'HKD', name: 'Hong Kong Dollar'),
    CurrencyInfo(isoCode: 'NZD', name: 'New Zealand Dollar'),
    CurrencyInfo(isoCode: 'ZAR', name: 'South African Rand'),
    CurrencyInfo(isoCode: 'NGN', name: 'Nigerian Naira'),
    CurrencyInfo(isoCode: 'UAH', name: 'Ukrainian Hryvnia'),
    CurrencyInfo(isoCode: 'IDR', name: 'Indonesian Rupiah'),
    CurrencyInfo(isoCode: 'MYR', name: 'Malaysian Ringgit'),
    CurrencyInfo(isoCode: 'PHP', name: 'Philippine Peso'),
    // East & Southeast Asia
    CurrencyInfo(isoCode: 'TWD', name: 'Taiwan Dollar'),
    CurrencyInfo(isoCode: 'VND', name: 'Vietnamese Dong'),
    CurrencyInfo(isoCode: 'MMK', name: 'Myanmar Kyat'),
    CurrencyInfo(isoCode: 'KHR', name: 'Cambodian Riel'),
    CurrencyInfo(isoCode: 'BND', name: 'Brunei Dollar'),
    // South Asia
    CurrencyInfo(isoCode: 'PKR', name: 'Pakistani Rupee'),
    CurrencyInfo(isoCode: 'BDT', name: 'Bangladeshi Taka'),
    CurrencyInfo(isoCode: 'LKR', name: 'Sri Lankan Rupee'),
    CurrencyInfo(isoCode: 'NPR', name: 'Nepalese Rupee'),
    // Middle East
    CurrencyInfo(isoCode: 'QAR', name: 'Qatari Riyal'),
    CurrencyInfo(isoCode: 'KWD', name: 'Kuwaiti Dinar'),
    CurrencyInfo(isoCode: 'BHD', name: 'Bahraini Dinar'),
    CurrencyInfo(isoCode: 'OMR', name: 'Omani Rial'),
    CurrencyInfo(isoCode: 'JOD', name: 'Jordanian Dinar'),
    CurrencyInfo(isoCode: 'IRR', name: 'Iranian Rial'),
    CurrencyInfo(isoCode: 'IQD', name: 'Iraqi Dinar'),
    // Central Asia & Caucasus
    CurrencyInfo(isoCode: 'KZT', name: 'Kazakhstani Tenge'),
    CurrencyInfo(isoCode: 'UZS', name: 'Uzbekistani Som'),
    CurrencyInfo(isoCode: 'GEL', name: 'Georgian Lari'),
    CurrencyInfo(isoCode: 'AZN', name: 'Azerbaijani Manat'),
    CurrencyInfo(isoCode: 'AMD', name: 'Armenian Dram'),
    // Africa
    CurrencyInfo(isoCode: 'EGP', name: 'Egyptian Pound'),
    CurrencyInfo(isoCode: 'MAD', name: 'Moroccan Dirham'),
    CurrencyInfo(isoCode: 'DZD', name: 'Algerian Dinar'),
    CurrencyInfo(isoCode: 'TND', name: 'Tunisian Dinar'),
    CurrencyInfo(isoCode: 'KES', name: 'Kenyan Shilling'),
    CurrencyInfo(isoCode: 'ETB', name: 'Ethiopian Birr'),
    CurrencyInfo(isoCode: 'GHS', name: 'Ghanaian Cedi'),
    CurrencyInfo(isoCode: 'TZS', name: 'Tanzanian Shilling'),
    CurrencyInfo(isoCode: 'UGX', name: 'Ugandan Shilling'),
    CurrencyInfo(isoCode: 'XOF', name: 'West African CFA Franc'),
    CurrencyInfo(isoCode: 'XAF', name: 'Central African CFA Franc'),
    // Latin America
    CurrencyInfo(isoCode: 'ARS', name: 'Argentine Peso'),
    CurrencyInfo(isoCode: 'CLP', name: 'Chilean Peso'),
    CurrencyInfo(isoCode: 'COP', name: 'Colombian Peso'),
    CurrencyInfo(isoCode: 'PEN', name: 'Peruvian Sol'),
    CurrencyInfo(isoCode: 'UYU', name: 'Uruguayan Peso'),
    CurrencyInfo(isoCode: 'BOB', name: 'Bolivian Boliviano'),
    CurrencyInfo(isoCode: 'PYG', name: 'Paraguayan Guaraní'),
    CurrencyInfo(isoCode: 'GTQ', name: 'Guatemalan Quetzal'),
    CurrencyInfo(isoCode: 'DOP', name: 'Dominican Peso'),
    // Europe (non-euro)
    CurrencyInfo(isoCode: 'BGN', name: 'Bulgarian Lev'),
    CurrencyInfo(isoCode: 'RSD', name: 'Serbian Dinar'),
    CurrencyInfo(isoCode: 'ISK', name: 'Icelandic Króna'),
    CurrencyInfo(isoCode: 'BAM', name: 'Bosnian Convertible Mark'),
    CurrencyInfo(isoCode: 'ALL', name: 'Albanian Lek'),
    CurrencyInfo(isoCode: 'MKD', name: 'Macedonian Denar'),
    CurrencyInfo(isoCode: 'MDL', name: 'Moldovan Leu'),
    CurrencyInfo(isoCode: 'BYN', name: 'Belarusian Ruble'),
    // Cryptocurrencies
    CurrencyInfo(isoCode: 'BTC', name: 'Bitcoin'),
    CurrencyInfo(isoCode: 'ETH', name: 'Ethereum'),
    CurrencyInfo(isoCode: 'USDT', name: 'Tether'),
    CurrencyInfo(isoCode: 'SOL', name: 'Solana'),
  ];

  static CurrencyInfo? byCode(String isoCode) {
    final upperCode = isoCode.toUpperCase();
    try {
      return allCurrencies.firstWhere(
        (c) => c.isoCode == upperCode,
      );
    } catch (_) {
      try {
        return _customCurrencies.firstWhere(
          (c) => c.isoCode == upperCode,
        );
      } catch (_) {
        return null;
      }
    }
  }
}
