import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/service-config.dart';

void main() {
  setUp(() => ServiceConfig.localTimezone = 'UTC');

  Record transfer(double sent, double? received) => Record(
    -sent,
    'Transfer',
    null,
    DateTime.utc(2026),
    walletId: 1,
    transferWalletId: 2,
    transferValue: received,
  );

  test('rate is derived from amounts and survives serialization', () {
    final record = transfer(100, 92);
    expect(record.transferExchangeRate, 0.92);
    expect(Record.fromMap(record.toMap()).transferExchangeRate, 0.92);
    expect(record.copyWith(transferValue: 95).transferExchangeRate, 0.95);
  });

  test('missing, zero and non-finite amounts have no exchange rate', () {
    for (final record in [
      transfer(100, null),
      transfer(0, 92),
      transfer(100, 0),
      transfer(100, -92),
      transfer(double.infinity, 92),
      transfer(100, double.nan),
      transfer(100, double.infinity),
      transfer(1e-300, 1e300),
      transfer(1e300, 1e-300),
    ]) {
      expect(record.transferExchangeRate, isNull);
    }
    expect(
      Record(
        -100,
        '',
        null,
        DateTime.utc(2026),
        transferValue: 92,
      ).transferExchangeRate,
      isNull,
    );
  });

  test('recurring patterns preserve the received amount', () {
    final pattern = RecurrentRecordPattern.fromRecord(
      transfer(100, 92),
      RecurrentPeriod.EveryMonth,
    );
    expect(RecurrentRecordPattern.fromMap(pattern.toMap()).transferValue, 92);
  });
}
