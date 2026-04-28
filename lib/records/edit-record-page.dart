// file: edit-record-page.dart

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:piggybank/categories/categories-tab-page-view.dart';
import 'package:piggybank/components/tag_chip.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';

import '../components/category_icon_circle.dart';
import '../helpers/date_picker_utils.dart';
import '../models/recurrent-record-pattern.dart';
import '../models/wallet.dart';
import '../settings/constants/preferences-keys.dart';
import '../settings/preferences-utils.dart';
import 'components/tag_selection_dialog.dart';
import 'components/wallet_transfer_row.dart';

class EditRecordPage extends StatefulWidget {
  final Record? passedRecord;
  final Category? passedCategory;
  final RecurrentRecordPattern? passedRecurrentRecordPattern;
  final bool readOnly;

  EditRecordPage(
      {Key? key,
      this.passedRecord,
      this.passedCategory,
      this.passedRecurrentRecordPattern,
      this.readOnly = false})
      : super(key: key);

  @override
  EditRecordPageState createState() => EditRecordPageState(this.passedRecord,
      this.passedCategory, this.passedRecurrentRecordPattern, this.readOnly);
}

class EditRecordPageState extends State<EditRecordPage> {
  DatabaseInterface database = ServiceConfig.database;
  TextEditingController _textEditingController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Record? record;

  Record? passedRecord;
  Category? passedCategory;
  bool readOnly = false;
  RecurrentRecordPattern? passedRecurrentRecordPattern;

  RecurrentPeriod? recurrentPeriod;
  int? recurrentPeriodIndex;

  late String currency;
  DateTime? lastCharInsertedMillisecond;
  late bool enableRecordNameSuggestions;
  late int amountInputKeyboardTypeIndex;

  DateTime? localDisplayDate;
  DateTime? localDisplayEndDate;

  Set<String> _selectedTags = {};
  Set<String> _suggestedTags = {};

  Wallet? _selectedWallet;
  Wallet? _selectedDestinationWallet;
  int _totalWalletCount = 0;
  final _walletNameSizeGroup = AutoSizeGroup();
  final _dateTimeSizeGroup = AutoSizeGroup();

  bool _hasTime = false;
  TimeOfDay? _selectedTime;

  // Original values captured at init to detect changes in pattern-linked records
  DateTime? _originalUtcDateTime;
  double? _originalValue;

  final autoDec = getAmountInputAutoDecimalShift();

  EditRecordPageState(this.passedRecord, this.passedCategory,
      this.passedRecurrentRecordPattern, this.readOnly);

  static final recurrentIntervalDropdownList = [
    DropdownMenuItem<int>(
        value: RecurrentPeriod.EveryDay.index,
        child: Text("Every day".i18n, style: TextStyle(fontSize: 18.0))),
    DropdownMenuItem<int>(
        value: RecurrentPeriod.EveryWeek.index,
        child: Text("Every week".i18n, style: TextStyle(fontSize: 18.0))),
    DropdownMenuItem<int>(
        value: RecurrentPeriod.EveryTwoWeeks.index,
        child: Text("Every two weeks".i18n, style: TextStyle(fontSize: 18.0))),
    DropdownMenuItem<int>(
        value: RecurrentPeriod.EveryFourWeeks.index,
        child: Text("Every four weeks".i18n, style: TextStyle(fontSize: 18.0))),
    DropdownMenuItem<int>(
      value: RecurrentPeriod.EveryMonth.index,
      child: Text("Every month".i18n, style: TextStyle(fontSize: 18.0)),
    ),
    DropdownMenuItem<int>(
      value: RecurrentPeriod.EveryThreeMonths.index,
      child: Text("Every three months".i18n, style: TextStyle(fontSize: 18.0)),
    ),
    DropdownMenuItem<int>(
      value: RecurrentPeriod.EveryFourMonths.index,
      child: Text("Every four months".i18n, style: TextStyle(fontSize: 18.0)),
    ),
    DropdownMenuItem<int>(
      value: RecurrentPeriod.EveryYear.index,
      child: Text("Every year".i18n, style: TextStyle(fontSize: 18.0)),
    )
  ];

  @override
  void initState() {
    super.initState();
    enableRecordNameSuggestions = PreferencesUtils.getOrDefault<bool>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.enableRecordNameSuggestions)!;
    amountInputKeyboardTypeIndex = PreferencesUtils.getOrDefault<int>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.amountInputKeyboardType)!;

    // Loading parameters passed to the page

    if (passedRecord != null) {
      // I am editing an existing record
      record = passedRecord;
      // Capture original values to detect changes for pattern-linked records
      _originalUtcDateTime = passedRecord!.utcDateTime;
      _originalValue = passedRecord!.value;
      // Use the localDateTime getter for display purposes
      localDisplayDate = passedRecord!.localDateTime;
      // Initialize time if the record has a non-midnight time
      final localDT = passedRecord!.localDateTime;
      if (localDT.hour != 0 || localDT.minute != 0) {
        _hasTime = true;
        _selectedTime = TimeOfDay(hour: localDT.hour, minute: localDT.minute);
      }
      _textEditingController.text =
          getCurrencyValueString(record!.value!.abs(), turnOffGrouping: false);
      if (record!.recurrencePatternId != null) {
        database
            .getRecurrentRecordPattern(record!.recurrencePatternId)
            .then((value) {
          if (value != null) {
            setState(() {
              recurrentPeriod = value.recurrentPeriod;
              recurrentPeriodIndex = value.recurrentPeriod!.index;
              localDisplayEndDate = value.localEndDate;
            });
          }
        });
      }
      // Initialize selected tags for existing record
      _selectedTags = Set.from(record!.tags);
    } else if (passedRecurrentRecordPattern != null) {
      // I am editing a recurrent pattern
      // Instantiate a new Record object from the pattern
      record = Record(
        passedRecurrentRecordPattern!.value,
        passedRecurrentRecordPattern!.title,
        passedRecurrentRecordPattern!.category,
        // The record's utcDateTime is from the pattern's utcDateTime
        passedRecurrentRecordPattern!.utcDateTime,
        // The record's timezone name is from the pattern's timezone name
        timeZoneName: passedRecurrentRecordPattern!.timeZoneName,
        description: passedRecurrentRecordPattern!.description,
        tags: passedRecurrentRecordPattern!.tags, // Pass tags from pattern
        walletId: passedRecurrentRecordPattern!.walletId,
        transferWalletId: passedRecurrentRecordPattern!.transferWalletId,
        transferValue: passedRecurrentRecordPattern!.transferValue,
        profileId: passedRecurrentRecordPattern!.profileId,
      );
      // Use the localDateTime for display
      localDisplayDate = passedRecurrentRecordPattern!.localDateTime;
      localDisplayEndDate = passedRecurrentRecordPattern!.localEndDate;
      // Initialize time if the recurrent pattern has a non-midnight time
      final localDT = passedRecurrentRecordPattern!.localDateTime;
      if (localDT.hour != 0 || localDT.minute != 0) {
        _hasTime = true;
        _selectedTime = TimeOfDay(hour: localDT.hour, minute: localDT.minute);
      }

      _textEditingController.text =
          getCurrencyValueString(record!.value!.abs(), turnOffGrouping: true);
      setState(() {
        recurrentPeriod = passedRecurrentRecordPattern!.recurrentPeriod;
        recurrentPeriodIndex =
            passedRecurrentRecordPattern!.recurrentPeriod!.index;
      });
      // Initialize selected tags for existing recurrent pattern
      _selectedTags = Set.from(passedRecurrentRecordPattern!.tags);
    } else {
      // I am adding a new record
      // Create a new record with a UTC timestamp and the current local timezone
      final now = DateTime.now();
      record = Record(null, null, passedCategory, now.toUtc());
      localDisplayDate = record!.localDateTime;
      _hasTime = true;
      _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
      _selectedTags = {};
      if (autoDec && record!.value == null) {
        final decSep = getDecimalSeparator();
        final decDigits = getNumberDecimalDigits();

        final zeroText = decDigits <= 0
            ? '0'
            : '0$decSep${List.filled(decDigits, '0').join()}';

        _textEditingController.value = _textEditingController.value.copyWith(
          text: zeroText,
          selection: TextSelection.collapsed(offset: zeroText.length),
          composing: TextRange.empty,
        );

        changeRecordValue(zeroText);
      }
    }

    // Load most used tags for the current category
    if (record?.category != null) {
      _loadSuggestedTags();
    }

    // Load wallet
    _initWallet();

    // Keyboard listeners initializations (the same as before)
    _textEditingController.addListener(() async {
      var text = _textEditingController.text.toLowerCase();
      await Future.delayed(Duration(seconds: 2));
      var textAfterPause = _textEditingController.text.toLowerCase();
      if (text == textAfterPause) {
        solveMathExpressionAndUpdateController(
          _textEditingController,
          onSolved: changeRecordValue,
        );
      }
    });

    String initialValue = record?.title ?? "";
    _typeAheadController.text = initialValue;
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _typeAheadController.dispose();
    super.dispose();
  }

  Widget _createAddNoteCard() {
    if (readOnly && record!.description == null) {
      return Container();
    }
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 40.0, top: 10, right: 16, left: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              width: 40,
              child: Center(
                child: Icon(
                  Icons.notes,
                  size: 28,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              identifier: 'note-field',
              child: TextFormField(
                  onChanged: (text) {
                    setState(() {
                      record!.description = text;
                    });
                  },
                  enabled: !readOnly,
                  style: TextStyle(
                      fontSize: 18.0,
                      color: Theme.of(context).colorScheme.onSurface),
                  initialValue: record!.description,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: "Add a note".i18n,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(20, 10, 10, 10),
                      label: Text("Note"))),
            ),
          ),
        ],
      ),
    );
  }

  final TextEditingController _typeAheadController = TextEditingController();

  Widget _createTitleCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: Icon(
                Icons.title,
                size: 28,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: TypeAheadField<String>(
              controller: _typeAheadController,
              builder: (context, controller, focusNode) {
                return Semantics(
                  identifier: 'record-name-field',
                  child: TextFormField(
                      enabled: !readOnly,
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (text) {
                        setState(() {
                          record!.title = text;
                        });
                      },
                      style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurface),
                      maxLines: 1,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          contentPadding: EdgeInsets.fromLTRB(20, 10, 10, 10),
                          border: InputBorder.none,
                          hintText: record!.category!.name,
                          labelText: "Record name".i18n)),
                );
              },
              suggestionsCallback: (search) {
                if (search.isNotEmpty && enableRecordNameSuggestions) {
                  return database.suggestedRecordTitles(
                      search, record!.category!.name!);
                }
                return null;
              },
              itemBuilder: (context, record) {
                return ListTile(
                  title: Text(record),
                );
              },
              onSelected: (selectedTitle) => {
                _typeAheadController.text = selectedTitle,
                setState(() {
                  record!.title = selectedTitle;
                })
              },
              hideOnEmpty: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _createCategoryCard() {
    return InkWell(
      onTap: () async {
        if (readOnly) {
          return; // do nothing
        }
        var selectedCategory = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CategoryTabPageView()),
        );
        if (selectedCategory != null) {
          setState(() {
            record!.category = selectedCategory;
            changeRecordValue(_textEditingController.text
                .toLowerCase()); // Handle sign change
            // Transfers only apply to expenses; clear destination if switching to income
            if (selectedCategory.categoryType == CategoryType.income) {
              _selectedDestinationWallet = null;
            }
          });
        }
      },
      child: Semantics(
        identifier: 'category-field',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CategoryIconCircle(
                  iconEmoji: record!.category!.iconEmoji,
                  iconDataFromDefaultIconSet: record!.category!.icon,
                  backgroundColor: record!.category!.color),
              Container(
                margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                child: Text(
                  record!.category!.name!,
                  style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  goToPremiumSplashScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PremiumSplashScreen()),
    );
  }

  Widget _createWalletCard() {
    final bool isExpense =
        record?.category?.categoryType == CategoryType.expense;
    return WalletTransferRow(
      selectedWallet: _selectedWallet,
      selectedDestinationWallet: _selectedDestinationWallet,
      showTransferSide: isExpense && _totalWalletCount > 1,
      readOnly: readOnly,
      walletNameSizeGroup: _walletNameSizeGroup,
      onSourceChanged: (wallet) {
        setState(() {
          _selectedWallet = wallet;
          if (_selectedDestinationWallet?.id == wallet?.id) {
            _selectedDestinationWallet = null;
          }
        });
      },
      onDestinationChanged: (wallet) {
        setState(() => _selectedDestinationWallet = wallet);
      },
    );
  }

  Widget _createDateAndRepeatCard() {
    final bool isRecordFromPattern = record!.recurrencePatternId != null;

    final bool showRepeatRow = record!.id == null || recurrentPeriod != null;
    final bool showEndDateRow = recurrentPeriod != null &&
        (!isRecordFromPattern || localDisplayEndDate != null);

    final bool canChangeRepeat = ServiceConfig.isPremium &&
        !readOnly &&
        record!.id == null &&
        record!.recurrencePatternId == null;
    final bool canChangeEndDate = !readOnly && !isRecordFromPattern;

    final bool showClearRepeat = record!.id == null &&
        record!.recurrencePatternId == null &&
        recurrentPeriod != null;
    final bool showClearEndDate =
        localDisplayEndDate != null && record!.recurrencePatternId == null;

    final bool showProLabel = !ServiceConfig.isPremium && !isRecordFromPattern;

    return _buildDateRepeatSection(
      showRepeatRow: showRepeatRow,
      showEndDateRow: showEndDateRow,
      canChangeRepeat: canChangeRepeat,
      canChangeEndDate: canChangeEndDate,
      showClearRepeat: showClearRepeat,
      showClearEndDate: showClearEndDate,
      showProLabel: showProLabel,
    );
  }

  Widget _buildDateRepeatSection({
    required bool showRepeatRow,
    required bool showEndDateRow,
    required bool canChangeRepeat,
    required bool canChangeEndDate,
    required bool showClearRepeat,
    required bool showClearEndDate,
    required bool showProLabel,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, showRepeatRow ? 0 : 12),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  identifier: 'date-field',
                  child: InkWell(
                    onTap: () async {
                      if (readOnly) return;
                      FocusScope.of(context).unfocus();
                      DateTime initialDate = localDisplayDate ?? DateTime.now();
                      int firstDayOfWeek = getFirstDayOfWeekIndex();
                      DateTime? result = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime(1970),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                          builder: (BuildContext context, Widget? child) {
                            return DatePickerUtils
                                .buildDatePickerWithFirstDayOfWeek(
                                    context, child, firstDayOfWeek);
                          });
                      if (result != null) {
                        setState(() {
                          localDisplayDate = result;
                          _hasTime = false;
                          _selectedTime = null;
                          record!.utcDateTime =
                              DateTime(result.year, result.month, result.day)
                                  .toUtc();
                          record!.timeZoneName = ServiceConfig.localTimezone;
                        });
                      }
                    },
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Center(
                            child: Icon(
                              Icons.calendar_today,
                              size: 28,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Container(
                            margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                            child: AutoSizeText(
                              getDateStr(localDisplayDate, shortYear: true),
                              maxLines: 1,
                              minFontSize: 10,
                              group: _dateTimeSizeGroup,
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Clock icon as separator — same Padding(horizontal: 8) as
              // the arrow_forward in the wallet row, so they align exactly.
              InkWell(
                onTap: () async {
                  if (readOnly) return;
                  FocusScope.of(context).unfocus();
                  final TimeOfDay? result = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime ?? TimeOfDay.now(),
                  );
                  if (result != null) {
                    setState(() {
                      _hasTime = true;
                      _selectedTime = result;
                      DateTime date = localDisplayDate ?? DateTime.now();
                      DateTime localDateTime = DateTime(date.year, date.month,
                          date.day, result.hour, result.minute);
                      record!.utcDateTime = localDateTime.toUtc();
                      record!.timeZoneName = ServiceConfig.localTimezone;
                    });
                  }
                },
                onLongPress: readOnly
                    ? null
                    : () {
                        setState(() {
                          _hasTime = false;
                          _selectedTime = null;
                          DateTime date = localDisplayDate ?? DateTime.now();
                          record!.utcDateTime =
                              DateTime(date.year, date.month, date.day).toUtc();
                          record!.timeZoneName = ServiceConfig.localTimezone;
                        });
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.access_time,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  identifier: 'time-field',
                  child: InkWell(
                    onTap: () async {
                      if (readOnly) return;
                      FocusScope.of(context).unfocus();
                      final TimeOfDay? result = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime ?? TimeOfDay.now(),
                      );
                      if (result != null) {
                        setState(() {
                          _hasTime = true;
                          _selectedTime = result;
                          DateTime date = localDisplayDate ?? DateTime.now();
                          DateTime localDateTime = DateTime(date.year,
                              date.month, date.day, result.hour, result.minute);
                          record!.utcDateTime = localDateTime.toUtc();
                          record!.timeZoneName = ServiceConfig.localTimezone;
                        });
                      }
                    },
                    onLongPress: readOnly
                        ? null
                        : () {
                            setState(() {
                              _hasTime = false;
                              _selectedTime = null;
                              DateTime date =
                                  localDisplayDate ?? DateTime.now();
                              record!.utcDateTime =
                                  DateTime(date.year, date.month, date.day)
                                      .toUtc();
                              record!.timeZoneName =
                                  ServiceConfig.localTimezone;
                            });
                          },
                    child: Container(
                      margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                      child: AutoSizeText(
                        _hasTime && _selectedTime != null
                            ? _selectedTime!.format(context)
                            : "Add time".i18n,
                        maxLines: 1,
                        minFontSize: 10,
                        group: _dateTimeSizeGroup,
                        style: TextStyle(
                          fontSize: 18,
                          color: _hasTime && _selectedTime != null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Visibility(
          visible: showRepeatRow,
          child: Column(
            children: [
              Divider(
                indent: 75,
                thickness: 1,
              ),
              Semantics(
                identifier: 'repeat-field',
                child: InkWell(
                    child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            16, 0, 16, showEndDateRow ? 0 : 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Center(
                                child: Icon(Icons.repeat,
                                    size: 28,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.only(left: 20, right: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                        child: DropdownButton<int>(
                                      iconSize: 0.0,
                                      items: recurrentIntervalDropdownList,
                                      onChanged: canChangeRepeat
                                          ? (value) {
                                              setState(() {
                                                recurrentPeriodIndex = value;
                                                recurrentPeriod =
                                                    RecurrentPeriod
                                                        .values[value!];
                                              });
                                            }
                                          : null,
                                      onTap: () {
                                        FocusScope.of(context).unfocus();
                                      },
                                      value: recurrentPeriodIndex,
                                      underline: SizedBox(),
                                      isExpanded: true,
                                      hint: recurrentPeriod == null
                                          ? Text(
                                              "Not repeat".i18n,
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant),
                                            )
                                          : Text(
                                              recurrentPeriodString(
                                                  recurrentPeriod),
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.normal,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant),
                                            ),
                                    )),
                                    Visibility(
                                      child: getProLabel(labelFontSize: 12.0),
                                      visible: showProLabel,
                                    ),
                                    Visibility(
                                      child: IconButton(
                                        icon: Icon(Icons.close,
                                            size: 28,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface),
                                        onPressed: () {
                                          setState(() {
                                            recurrentPeriod = null;
                                            recurrentPeriodIndex = null;
                                          });
                                        },
                                      ),
                                      visible: showClearRepeat,
                                    )
                                  ],
                                ),
                              ),
                            )
                          ],
                        ))),
              ),
              // End Date Picker - visible when recurrent period is selected and end date is set
              Visibility(
                visible: showEndDateRow,
                child: Column(
                  children: [
                    Divider(
                      indent: 75,
                      thickness: 1,
                    ),
                    Semantics(
                      identifier: 'end-date-field',
                      child: InkWell(
                          onTap: canChangeEndDate
                              ? () async {
                                  FocusScope.of(context).unfocus();
                                  DateTime initialDate = localDisplayEndDate ??
                                      DateTime.now().add(Duration(days: 365));
                                  int firstDayOfWeek = getFirstDayOfWeekIndex();
                                  DateTime? result = await showDatePicker(
                                      context: context,
                                      initialDate: initialDate,
                                      firstDate:
                                          localDisplayDate ?? DateTime(1970),
                                      lastDate: DateTime.now()
                                          .add(Duration(days: 365 * 10)),
                                      builder: (BuildContext context,
                                          Widget? child) {
                                        return DatePickerUtils
                                            .buildDatePickerWithFirstDayOfWeek(
                                                context, child, firstDayOfWeek);
                                      });
                                  if (result != null) {
                                    setState(() {
                                      localDisplayEndDate = result;
                                    });
                                  }
                                }
                              : null,
                          child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Center(
                                      child: Icon(
                                        Icons.event_busy,
                                        size: 28,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      margin:
                                          EdgeInsets.only(left: 20, right: 10),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "End Date (optional)".i18n,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(alpha: 0.7),
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  localDisplayEndDate != null
                                                      ? getDateStr(
                                                          localDisplayEndDate!)
                                                      : "Not set".i18n,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    color: localDisplayEndDate !=
                                                            null
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Visibility(
                                            child: IconButton(
                                              icon: Icon(Icons.close,
                                                  size: 28,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface),
                                              onPressed: () {
                                                setState(() {
                                                  localDisplayEndDate = null;
                                                });
                                              },
                                            ),
                                            visible: showClearEndDate,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _createAmountCard() {
    final decimalSep = getDecimalSeparator();
    final groupSep = getGroupingSeparator();
    final decDigits = getNumberDecimalDigits();
    final shouldAutofocus = !readOnly &&
        passedRecord == null &&
        passedRecurrentRecordPattern == null;
    final zeroHint = (autoDec && decDigits > 0)
        ? '0$decimalSep${List.filled(decDigits, '0').join()}'
        : '0';
    String categorySign =
        record?.category?.categoryType == CategoryType.expense ? "-" : "+";
    return Container(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: IntrinsicHeight(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 25, bottom: 10),
              child: SizedBox(
                width: 40,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        categorySign,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
                child: Container(
              padding: EdgeInsets.all(10),
              margin: EdgeInsets.only(right: 10),
              child: Semantics(
                identifier: 'amount-field',
                child: TextFormField(
                    enabled: !readOnly,
                    controller: _textEditingController,
                    inputFormatters: buildAmountInputFormatters(
                      decimalSep: decimalSep,
                      groupSep: groupSep,
                      autoDec: autoDec,
                      decDigits: decDigits,
                    ),
                    autofocus: shouldAutofocus,
                    onChanged: (text) {
                      changeRecordValue(text);
                    },
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "Please enter a value".i18n;
                      }
                      var numericValue = tryParseCurrencyString(value);
                      if (numericValue == null) {
                        return "Not a valid format (use for example: %s)"
                            .i18n
                            .fill([
                          getCurrencyValueString(1234.20, turnOffGrouping: true)
                        ]);
                      }
                      return null;
                    },
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 32.0,
                        color: Theme.of(context).colorScheme.onSurface),
                    keyboardType: getAmountInputKeyboardType(
                        amountInputKeyboardTypeIndex),
                    decoration: InputDecoration(
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        hintText: zeroHint,
                        labelText: "Amount".i18n)),
              ),
            ))
          ],
        )));
  }

  void changeRecordValue(String text) {
    var numericValue = tryParseCurrencyString(text);
    if (numericValue != null) {
      numericValue = numericValue.abs();
      if (record!.category!.categoryType == CategoryType.expense) {
        numericValue = numericValue * -1;
      }
      record!.value = numericValue;
    }
  }

  void _recalculateTransferValue() {
    if (_selectedWallet?.currency == null ||
        _selectedDestinationWallet?.currency == null ||
        record?.value == null) {
      record?.transferValue = null;
      return;
    }
    final src = _selectedWallet!.currency!;
    final dest = _selectedDestinationWallet!.currency!;
    if (src == dest) {
      record!.transferValue = null;
      return;
    }
    record!.transferValue = convertAmount(record!.value!.abs(), src, dest);
  }

  void _appendTransferNoteToDescription() {
    final srcWallet = _selectedWallet;
    final destWallet = _selectedDestinationWallet;
    if (srcWallet?.currency == null ||
        destWallet?.currency == null ||
        record?.transferValue == null ||
        srcWallet!.currency == destWallet!.currency) {
      return;
    }
    final srcCurrency = srcWallet.currency!;
    final destCurrency = destWallet.currency!;
    final srcFormatted =
        formatCurrencyAmount(record!.value!.abs(), srcCurrency);
    final destFormatted =
        formatCurrencyAmount(record!.transferValue!, destCurrency);
    final rateString = getConversionRateString(srcCurrency, destCurrency);

    final buffer = StringBuffer();
    buffer.write('$srcFormatted → $destFormatted');
    if (rateString != null) {
      buffer.write(' ($rateString)');
    }

    final existing = record!.description?.trim();
    if (existing == null || existing.isEmpty) {
      record!.description = buffer.toString();
    } else if (!existing.contains(buffer.toString())) {
      record!.description = '$existing\n${buffer.toString()}';
    }
  }

  addOrUpdateRecord() async {
    _recalculateTransferValue();
    record!.tags = _selectedTags; // Assign selected tags to the record
    record!.walletId = _selectedWallet?.id;
    record!.transferWalletId = _selectedDestinationWallet?.id;
    if (record!.recurrencePatternId != null) {
      final dateChanged = _originalUtcDateTime != null &&
          record!.utcDateTime.millisecondsSinceEpoch !=
              _originalUtcDateTime!.millisecondsSinceEpoch;
      final amountChanged =
          _originalValue != null && record!.value != _originalValue;
      if (dateChanged || amountChanged) {
        record!.recurrencePatternId = null;
      }
    }
    if (record!.id == null) {
      _appendTransferNoteToDescription();
      await database.addRecord(record);
    } else {
      await database.updateRecordById(record!.id, record);
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _initWallet() async {
    final allWallets = await database.getAllWallets(
        profileId: ProfileService.instance.activeProfileId);
    final activeWallets = allWallets.where((w) => !w.isArchived).toList();

    Wallet? walletToSelect;
    if (record?.walletId != null) {
      // Fall back to the Predefined Wallet if the assigned wallet no longer exists
      walletToSelect = await database.getWalletById(record!.walletId!) ??
          await database.getPredefinedWallet() ??
          await database.getDefaultWallet();
    } else {
      // Start with the predefined wallet for new records
      walletToSelect = await database.getPredefinedWallet();
      if (walletToSelect == null && activeWallets.length == 1) {
        walletToSelect = activeWallets.first;
      }
      walletToSelect ??= await database.getDefaultWallet();
    }

    if (mounted) {
      setState(() {
        _selectedWallet = walletToSelect;
        _totalWalletCount = activeWallets.length;
      });
    }

    // Load destination wallet if editing an existing transfer
    if (record?.transferWalletId != null) {
      final destWallet =
          await database.getWalletById(record!.transferWalletId!);
      if (destWallet != null && mounted) {
        setState(() => _selectedDestinationWallet = destWallet);
      }
    }
  }

  Future<void> _loadSuggestedTags() async {
    if (record?.category != null) {
      Set<String> suggestedTags = Set();
      final mostUsedForCategory = (await database.getMostUsedTagsForCategory(
              record!.category!.name!, record!.category!.categoryType!))
          .take(4);
      final mostRecentTags = (await database.getRecentlyUsedTags()).take(4);
      suggestedTags.addAll(mostUsedForCategory);
      suggestedTags.addAll(mostRecentTags);
      suggestedTags.removeAll(_selectedTags);
      setState(() {
        _suggestedTags = suggestedTags;
      });
    }
  }

  recurrentPeriodHasBeenUpdated(RecurrentRecordPattern toSet) {
    bool recurrentPeriodHasChanged = toSet.recurrentPeriod!.index !=
        passedRecurrentRecordPattern!.recurrentPeriod!.index;
    // Compare the UTC timestamps
    bool startingDateHasChanged = toSet.utcDateTime.millisecondsSinceEpoch !=
        passedRecurrentRecordPattern!.utcDateTime.millisecondsSinceEpoch;
    return recurrentPeriodHasChanged || startingDateHasChanged;
  }

  addOrUpdateRecurrentPattern({id}) async {
    // Assign wallet and transfer fields before creating the pattern
    _recalculateTransferValue();
    record!.walletId = _selectedWallet?.id;
    record!.transferWalletId = _selectedDestinationWallet?.id;
    if (id == null) {
      _appendTransferNoteToDescription();
    }
    // Create a new recurrent pattern from the updated record
    RecurrentRecordPattern recordPattern = RecurrentRecordPattern.fromRecord(
      record!,
      recurrentPeriod!,
      id: id,
      utcEndDate: localDisplayEndDate?.toUtc(),
    );
    recordPattern.tags =
        _selectedTags; // Assign selected tags to the recurrent pattern
    if (id != null) {
      // Always use the current time to delete future records, not the pattern's
      // start date. Using the start date would delete all past historical records.
      final now = DateTime.now().toUtc();
      if (recurrentPeriodHasBeenUpdated(recordPattern)) {
        await database.deleteFutureRecordsByPatternId(id, now);
        await database.deleteRecurrentRecordPatternById(id);
        await database.addRecurrentRecordPattern(recordPattern);
      } else {
        await database.deleteFutureRecordsByPatternId(id, now);
        await database.updateRecordPatternById(id, recordPattern);
      }
    } else {
      await database.addRecurrentRecordPattern(recordPattern);
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openTagSelectionDialog() async {
    if (ServiceConfig.isPremium) {
      final selectedTags = await Navigator.push<Set<String>>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => TagSelectionDialog(
            initialSelectedTags: _selectedTags,
          ),
        ),
      );

      if (selectedTags != null) {
        setState(() {
          _selectedTags = selectedTags;
        });
      }
    } else {
      goToPremiumSplashScreen();
    }
  }

  AppBar _getAppBar() {
    final bgColor = Theme.of(context).colorScheme.secondaryContainer;
    final fgColor = Theme.of(context).colorScheme.onSecondaryContainer;
    return AppBar(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        title: Text(
          readOnly ? 'View record'.i18n : 'Edit record'.i18n,
        ),
        actions: <Widget>[
          Visibility(
              visible: (widget.passedRecord != null ||
                      widget.passedRecurrentRecordPattern != null) &&
                  !readOnly,
              child: IconButton(
                  icon: Semantics(
                      identifier: "delete-button",
                      child: const Icon(Icons.delete)),
                  tooltip: 'Delete'.i18n,
                  onPressed: () async {
                    AlertDialogBuilder deleteDialog =
                        AlertDialogBuilder("Critical action".i18n)
                            .addTrueButtonName("Yes".i18n)
                            .addFalseButtonName("No".i18n);
                    if (widget.passedRecord != null) {
                      deleteDialog = deleteDialog.addSubtitle(
                          "Do you really want to delete this record?".i18n);
                    } else {
                      deleteDialog = deleteDialog.addSubtitle(
                          "Do you really want to delete this recurrent record?"
                              .i18n);
                    }
                    var continueDelete = await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return deleteDialog.build(context);
                        });
                    if (continueDelete) {
                      if (widget.passedRecord != null) {
                        await database.deleteRecordById(record!.id);
                        final restoreAmount =
                            PreferencesUtils.getOrDefault<bool>(
                                ServiceConfig.sharedPreferences!,
                                PreferencesKeys.restoreAmountOnDelete)!;
                        if (!restoreAmount &&
                            record!.walletId != null &&
                            record!.value != null) {
                          final wallet =
                              await database.getWalletById(record!.walletId!);
                          if (wallet != null) {
                            wallet.initialAmount += record!.value!;
                            await database.updateWallet(wallet.id!, wallet);
                          }
                        }
                      } else {
                        String patternId =
                            widget.passedRecurrentRecordPattern!.id!;
                        // Use the current UTC time when deleting future records
                        await database.deleteFutureRecordsByPatternId(
                            patternId, DateTime.now().toUtc());
                        await database
                            .deleteRecurrentRecordPatternById(patternId);
                      }
                      Navigator.pop(context);
                    }
                  })),
        ]);
  }

  Widget _getForm() {
    return Container(
      margin: EdgeInsets.only(bottom: 80),
      child: Form(
        key: _formKey,
        child: Column(children: [
          _createAmountCard(),
          Divider(height: 1),
          _createTitleCard(),
          Divider(height: 1),
          _createCategoryCard(),
          Divider(height: 1),
          _createWalletCard(),
          Divider(height: 1),
          _createDateAndRepeatCard(),
          Divider(height: 1),
          _createTagsSection(),
          Divider(height: 1),
          _createAddNoteCard(),
        ]),
      ),
    );
  }

  Widget _createTagsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                child: Center(
                  child: Icon(
                    Icons.label_outline,
                    size: 28,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (readOnly && _selectedTags.isEmpty)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                    child: Text(
                      "No tags applied.".i18n,
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              if (!readOnly && _selectedTags.isEmpty)
                Expanded(
                  child: InkWell(
                    onTap: _openTagSelectionDialog,
                    child: Container(
                      margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                      width: double.infinity,
                      child: Text(
                        "Add tags".i18n,
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_selectedTags.isNotEmpty)
                Flexible(
                  child: Container(
                    margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: [
                        ..._selectedTags.map((tag) {
                          return TagChip(
                            labelText: tag,
                            isSelected: true,
                            onSelected: readOnly
                                ? null
                                : (selected) {
                                    setState(() {
                                      _selectedTags.remove(tag);
                                      _suggestedTags.add(tag);
                                    });
                                  },
                          );
                        }).toList(),
                        if (!readOnly)
                          TagChip(
                            labelText: "+",
                            isSelected: false,
                            onSelected: (selected) {
                              _openTagSelectionDialog();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (!readOnly && _suggestedTags.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(left: 60, bottom: 6),
              child: _createSuggestedTagsChips(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _createSuggestedTagsChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Suggested tags".i18n,
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        SizedBox(height: 5),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: [
            ..._suggestedTags.map((tag) {
              return TagChip(
                labelText: tag,
                isSelected: _selectedTags.contains(tag),
                onSelected: readOnly
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag);
                            _suggestedTags.remove(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
              );
            }).toList()
          ],
        ),
      ],
    );
  }

  isARecurrentPattern() {
    return recurrentPeriod != null && record?.recurrencePatternId == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _getAppBar(),
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(child: _getForm()),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  if (isARecurrentPattern()) {
                    String? recurrentPatternId;
                    if (passedRecurrentRecordPattern != null) {
                      recurrentPatternId =
                          this.passedRecurrentRecordPattern!.id;
                    }
                    await addOrUpdateRecurrentPattern(
                      id: recurrentPatternId,
                    );
                  } else {
                    await addOrUpdateRecord();
                  }
                }
              },
              tooltip: 'Save'.i18n,
              child: Semantics(
                  identifier: 'save-button', child: const Icon(Icons.save)),
            ),
    );
  }
}
