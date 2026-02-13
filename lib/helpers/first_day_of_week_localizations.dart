// lib/helpers/first_day_of_week_localizations.dart

import 'package:flutter/material.dart';

class FirstDayOfWeekLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  final LocalizationsDelegate<MaterialLocalizations> wrappedDelegate;
  final int firstDayOfWeek;

  const FirstDayOfWeekLocalizationsDelegate(this.wrappedDelegate, this.firstDayOfWeek);

  @override
  bool isSupported(Locale locale) => wrappedDelegate.isSupported(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    final MaterialLocalizations localizations = await wrappedDelegate.load(locale);
    
    // Convert preference value to Flutter's firstDayOfWeekIndex
    // Preferences: 0=System, 1=Sunday 6=Saturday, 7=Sunday
    // Flutter: 0=Sunday, 1=Monday etc
    int flutterFirstDayIndex;
    switch (firstDayOfWeek) {
      case 1: // Monday
        flutterFirstDayIndex = 1;
        break;
      case 6: // Saturday
        flutterFirstDayIndex = 6;
        break;
      case 7: // Sunday
        flutterFirstDayIndex = 0;
        break;
      default:
        // For system default (0) or any other value, use Monday as fallback
        flutterFirstDayIndex = 0;
        break;
    }
    
    return FirstDayOfWeekLocalizations(localizations, flutterFirstDayIndex);
  }

  @override
  bool shouldReload(FirstDayOfWeekLocalizationsDelegate old) {
    return old.firstDayOfWeek != firstDayOfWeek || old.wrappedDelegate != wrappedDelegate;
  }
}

class FirstDayOfWeekLocalizations extends DefaultMaterialLocalizations {
  final MaterialLocalizations _original;
  final int _firstDayOfWeekIndex;

  const FirstDayOfWeekLocalizations(this._original, this._firstDayOfWeekIndex);

  @override
  int get firstDayOfWeekIndex => _firstDayOfWeekIndex;

  // Forwarding methods to preserving original locale language

  @override String get alertDialogLabel => _original.alertDialogLabel;
  @override String get anteMeridiemAbbreviation => _original.anteMeridiemAbbreviation;
  @override String get backButtonTooltip => _original.backButtonTooltip;
  @override String get calendarModeButtonLabel => _original.calendarModeButtonLabel;
  @override String get cancelButtonLabel => _original.cancelButtonLabel;
  @override String get closeButtonLabel => _original.closeButtonLabel;
  @override String get closeButtonTooltip => _original.closeButtonTooltip;
  @override String get collapsedIconTapHint => _original.collapsedIconTapHint;
  @override String get continueButtonLabel => _original.continueButtonLabel;
  @override String get copyButtonLabel => _original.copyButtonLabel;
  @override String get cutButtonLabel => _original.cutButtonLabel;
  @override String get dateHelpText => _original.dateHelpText;
  @override String get dateInputLabel => _original.dateInputLabel;
  @override String get dateOutOfRangeLabel => _original.dateOutOfRangeLabel;
  @override String get datePickerHelpText => _original.datePickerHelpText;
  @override String get dateRangePickerHelpText => _original.dateRangePickerHelpText;
  @override String get dateSeparator => _original.dateSeparator;
  @override String get deleteButtonTooltip => _original.deleteButtonTooltip;
  @override String get dialModeButtonLabel => _original.dialModeButtonLabel;
  @override String get dialogLabel => _original.dialogLabel;
  @override String get drawerLabel => _original.drawerLabel;
  @override String get expandedIconTapHint => _original.expandedIconTapHint;
  @override String get hideAccountsLabel => _original.hideAccountsLabel;
  @override String get inputDateModeButtonLabel => _original.inputDateModeButtonLabel;
  @override String get inputTimeModeButtonLabel => _original.inputTimeModeButtonLabel;
  @override String get invalidDateFormatLabel => _original.invalidDateFormatLabel;
  @override String get invalidDateRangeLabel => _original.invalidDateRangeLabel;
  @override String get invalidTimeLabel => _original.invalidTimeLabel;
  @override String get licensesPageTitle => _original.licensesPageTitle;
  @override String get menuBarMenuLabel => _original.menuBarMenuLabel;
  @override String get modalBarrierDismissLabel => _original.modalBarrierDismissLabel;
  @override String get moreButtonTooltip => _original.moreButtonTooltip;
  @override String get nextMonthTooltip => _original.nextMonthTooltip;
  @override String get nextPageTooltip => _original.nextPageTooltip;
  @override String get okButtonLabel => _original.okButtonLabel;
  @override String get openAppDrawerTooltip => _original.openAppDrawerTooltip;
  @override String get pasteButtonLabel => _original.pasteButtonLabel;
  @override String get popupMenuLabel => _original.popupMenuLabel;
  @override String get postMeridiemAbbreviation => _original.postMeridiemAbbreviation;
  @override String get previousMonthTooltip => _original.previousMonthTooltip;
  @override String get previousPageTooltip => _original.previousPageTooltip;
  @override String get refreshIndicatorSemanticLabel => _original.refreshIndicatorSemanticLabel;
  @override String get rowsPerPageTitle => _original.rowsPerPageTitle;
  @override String get saveButtonLabel => _original.saveButtonLabel;
  @override ScriptCategory get scriptCategory => _original.scriptCategory;
  @override String get searchFieldLabel => _original.searchFieldLabel;
  @override String get selectAllButtonLabel => _original.selectAllButtonLabel;
  @override String get selectYearSemanticsLabel => _original.selectYearSemanticsLabel;
  @override String get showAccountsLabel => _original.showAccountsLabel;
  @override String get showMenuTooltip => _original.showMenuTooltip;
  @override String get signedInLabel => _original.signedInLabel;
  @override String get timePickerDialHelpText => _original.timePickerDialHelpText;
  @override String get timePickerHourLabel => _original.timePickerHourLabel;
  @override String get timePickerHourModeAnnouncement => _original.timePickerHourModeAnnouncement;
  @override String get timePickerInputHelpText => _original.timePickerInputHelpText;
  @override String get timePickerMinuteLabel => _original.timePickerMinuteLabel;
  @override String get timePickerMinuteModeAnnouncement => _original.timePickerMinuteModeAnnouncement;
  @override String get unspecifiedDate => _original.unspecifiedDate;
  @override String get unspecifiedDateRange => _original.unspecifiedDateRange;
  @override String get viewLicensesButtonLabel => _original.viewLicensesButtonLabel;

  @override String aboutListTileTitle(String applicationName) => _original.aboutListTileTitle(applicationName);
  @override String formatCompactDate(DateTime date) => _original.formatCompactDate(date);
  @override String formatDecimal(int number) => _original.formatDecimal(number);
  @override String formatFullDate(DateTime date) => _original.formatFullDate(date);
  @override String formatHour(TimeOfDay timeOfDay, {bool alwaysUse24HourFormat = false}) => _original.formatHour(timeOfDay, alwaysUse24HourFormat: alwaysUse24HourFormat);
  @override String formatMediumDate(DateTime date) => _original.formatMediumDate(date);
  @override String formatMinute(TimeOfDay timeOfDay) => _original.formatMinute(timeOfDay);
  @override String formatMonthYear(DateTime date) => _original.formatMonthYear(date);
  @override String formatShortDate(DateTime date) => _original.formatShortDate(date);
  @override String formatShortMonthDay(DateTime date) => _original.formatShortMonthDay(date);
  @override String formatTimeOfDay(TimeOfDay timeOfDay, {bool alwaysUse24HourFormat = false}) => _original.formatTimeOfDay(timeOfDay, alwaysUse24HourFormat: alwaysUse24HourFormat);
  @override String formatYear(DateTime date) => _original.formatYear(date);
  @override String pageRowsInfoTitle(int firstRow, int lastRow, int rowCount, bool rowCountIsApproximate) => _original.pageRowsInfoTitle(firstRow, lastRow, rowCount, rowCountIsApproximate);
  @override DateTime? parseCompactDate(String? inputString) => _original.parseCompactDate(inputString);
  @override String tabLabel({required int tabIndex, required int tabCount}) => _original.tabLabel(tabIndex: tabIndex, tabCount: tabCount);
}
