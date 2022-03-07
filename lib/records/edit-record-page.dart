
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/categories/categories-tab-page-view.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './i18n/edit-record-page.i18n.dart';

import 'package:function_tree/function_tree.dart';


class EditRecordPage extends StatefulWidget {

  /// EditMovementPage is a page containing forms for the editing of a Movement object.
  /// EditMovementPage can take the movement object to edit as a constructor parameters
  /// or can create a new Movement otherwise.

  Record passedRecord;
  Category passedCategory;
  EditRecordPage({Key key, this.passedRecord, this.passedCategory}) : super(key: key);

  @override
  EditRecordPageState createState() => EditRecordPageState(this.passedRecord, this.passedCategory);
}

class EditRecordPageState extends State<EditRecordPage> {

  DatabaseInterface database = ServiceConfig.database;
  TextEditingController _textEditingController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Record record;

  Record passedRecord;
  Category passedCategory;
  RecurrentPeriod recurrentPeriod;
  int recurrentPeriodIndex;
  String currency;
  DateTime lastCharInsertedMillisecond;

  EditRecordPageState(this.passedRecord, this.passedCategory);

  static final dropDownList = [
    new DropdownMenuItem<int>(
    value: 0,
    child: new Text("Every day".i18n, style: TextStyle(fontSize: 20.0))
    ),
    new DropdownMenuItem<int>(
    value: 1,
    child: new Text("Every week".i18n, style: TextStyle(fontSize: 20.0))
    ),
    new DropdownMenuItem<int>(
    value: 2,
    child: new Text("Every month".i18n, style: TextStyle(fontSize: 20.0)),
    )
  ];

  Future<String> getCurrency() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('currency') ?? "€";
  }

  bool isMathExpression(String text) {
    bool containsOperator = false;
    containsOperator |= text.contains("+");
    containsOperator |= text.contains("-");
    containsOperator |= text.contains("*");
    containsOperator |= text.contains("/");
    containsOperator |= text.contains("%");
    return containsOperator;
  }

  void solveMathExpressionAndUpdateText() {
    var text = _textEditingController.text.toLowerCase();
    var newNum;
    if (isMathExpression(text)) {
      try {
        newNum = text.interpret();
      } catch (e) {
        stderr.writeln("Can't parse the expression");
      }
    }
    if (newNum != null) {
      text = newNum.toStringAsFixed(2);
      _textEditingController.value = _textEditingController.value.copyWith(
        text: text,
        selection:
        TextSelection(baseOffset: text.length, extentOffset: text.length),
        composing: TextRange.empty,
      );
      changeRecordValue(_textEditingController.text.toLowerCase());
    }
  }

  @override
  void initState() {
    super.initState();
    currency = "€";
    if (passedRecord != null) {
      record = passedRecord;
      _textEditingController.text = getCurrencyValueString(record.value.abs());
      if (record.recurrencePatternId != null) {
        database.getRecurrentRecordPattern(record.recurrencePatternId).then((value) {
          if (value != null) {
            setState(() {
              recurrentPeriod = value.recurrentPeriod;
              recurrentPeriodIndex = value.recurrentPeriod.index;
            });
          }
        });
      }
    } else {
      record = new Record(null, null, passedCategory, DateTime.now());
    }
    getCurrency().then((value) {
      setState(() {
        currency = value;
      });
    });

    // char validation
    _textEditingController.addListener(() {
      lastCharInsertedMillisecond = DateTime.now();
      var text = _textEditingController.text.toLowerCase();
      final exp = new RegExp(r'[^\d.\\+\-\*=/%x]');
      text = text.replaceAll(",", ".");
      text = text.replaceAll("x", "*");
      text = text.replaceAll(exp, "");
      _textEditingController.value = _textEditingController.value.copyWith(
        text: text,
        selection:
        TextSelection(baseOffset: text.length, extentOffset: text.length),
        composing: TextRange.empty,
      );
    });

    _textEditingController.addListener(() async {
      var text = _textEditingController.text.toLowerCase();
      await Future.delayed(Duration(seconds: 2));
      var textAfterPause = _textEditingController.text.toLowerCase();
      if (text == textAfterPause) {
        solveMathExpressionAndUpdateText();
      }
    });
  }


Widget _createAddNoteCard() {
    return Card(
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.only(bottom: 40.0, top: 10, right: 10, left: 10),
          child: TextFormField(
              onChanged: (text) {
                setState(() {
                  record.description = text;
                });
              },
              style: TextStyle(
                  fontSize: 22.0,
                  color: Colors.black
              ),
              initialValue: record.description,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Add a note".i18n,
              )
          ),
        ),
    );
  }

  Widget _createTitleCard() {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: TextFormField(
            onChanged: (text) {
              setState(() {
                record.title = text;
              });
            },
            style: TextStyle(
                fontSize: 22.0,
                color: Colors.black
            ),
            maxLines: 1,
            initialValue: record.title,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: EdgeInsets.all(10),
                border: InputBorder.none,
                hintText: record.category.name,
                labelText: "Record name".i18n
            )
        ),
      ),
    );
  }

  Widget _createCategoryCard() {
    return Card(
      elevation: 2,
      child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              InkWell(
                onTap: () async {
                  var selectedCategory = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CategoryTabPageView()),
                  );
                  if (selectedCategory != null) {
                    setState(() {
                      record.category = selectedCategory;
                      changeRecordValue(record.value.toString()); // Handle sign change
                    });
                  }
                },
                child: Row(
                  children: [
                    _createCategoryCirclePreview(40.0),
                    Container(
                      margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                      child: Text(record.category.name, style: TextStyle(fontSize: 20, color: Colors.blueAccent),),
                    )
                  ],
                ),
              ),
            ]
          )
      ),
    );
  }

  Widget _createCategoryCirclePreview(double size) {
    Category defaultCategory = Category("Missing".i18n, color: Category.colors[0], iconCodePoint: FontAwesomeIcons.question.codePoint);
    Category toRender = (record.category == null) ? defaultCategory : record.category;
    return Container(
        margin: EdgeInsets.all(10),
        child: ClipOval(
            child: Material(
                color: toRender.color, // button color
                child: InkWell(
                  splashColor: toRender.color, // inkwell color
                  child: SizedBox(width: size, height: size,
                    child: Icon(toRender.icon, color: Colors.white, size: size - 20,),
                  ),
                )
            )
        )
    );
  }

  goToPremiumSplashScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PremiumSplashScren()),
    );
  }

  Widget _createDateAndRepeatCard() {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            InkWell(
              onTap: () async {
                FocusScope.of(context).unfocus();
                DateTime now = DateTime.now();
                DateTime result = await showDatePicker(context: context,
                    initialDate: now,
                    firstDate: DateTime(1970), lastDate: DateTime.now());
                if (result != null) {
                  setState(() {
                    record.dateTime = result;
                  });
                }
              },
              child: Container(
                margin: EdgeInsets.fromLTRB(10, 10, 0, 10),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 28, color: Colors.blueAccent,),
                    Container(
                      margin: EdgeInsets.only(left: 20, right: 20),
                      child: Text(getDateStr(record.dateTime), style: TextStyle(fontSize: 20, color: Colors.blueAccent),),
                    )
                  ],
                )
              )
            ),
            Visibility(
              visible: record.id == null || recurrentPeriod != null, // when record comes from recurrent record
              child: Column(
                children: [
                  Divider(indent: 60, thickness: 1,),
                  InkWell(
                      child: Container(
                          margin: EdgeInsets.fromLTRB(10, 0, 0, 0),
                          child: Row(
                            children: [
                              Icon(Icons.repeat, size: 28, color: Colors.black54),
                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(left: 15, right: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                          child: new DropdownButton<int>(
                                            iconSize: 0.0,
                                            items: dropDownList,
                                            onChanged: ServiceConfig.isPremium && record.id == null ? (value) {
                                              setState(() {
                                                recurrentPeriodIndex = value;
                                                recurrentPeriod = RecurrentPeriod.values[value];
                                              });
                                            } : null,
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                            },
                                            value: recurrentPeriodIndex,
                                            underline: SizedBox(),
                                            isExpanded: true,
                                            hint: recurrentPeriod == null ? Container(
                                              margin: const EdgeInsets.only(left: 10.0),
                                              child: Text(
                                                "Repeat".i18n,
                                                style: TextStyle(fontSize: 20.0, color: Colors.black26),
                                              ),
                                            ) : Container(
                                              margin: const EdgeInsets.only(left: 10.0),
                                              child: Text(
                                                recurrentPeriodString(recurrentPeriod).i18n,
                                                style: TextStyle(fontSize: 20.0),
                                              ),
                                            ),
                                          )
                                      ),
                                      Visibility(
                                        child: getProLabel(labelFontSize: 12.0),
                                        visible: !ServiceConfig.isPremium,
                                      ),
                                      Visibility(
                                        child: new IconButton(
                                          icon: new Icon(Icons.close, size: 28, color: Colors.black54),
                                          onPressed: () {
                                            setState(() {
                                              recurrentPeriod = null;
                                              recurrentPeriodIndex = null;
                                            });
                                          },
                                        ),
                                        visible: record.id == null && recurrentPeriod != null,
                                      )
                                    ],
                                  ),
                                ),
                              )
                            ],
                          )
                      )
                  ),
                ],
              ),
            )
          ],
        )
      ),
    );
  }

  Widget _createAmountCard() {
    return Card(
      elevation: 2,
      child: Container(
        child: IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    margin: EdgeInsets.only(left: 20, right: 20),
                    child: Text(currency, style: TextStyle(fontSize: 32), textAlign: TextAlign.left),
                  ),
                ),
                VerticalDivider(endIndent: 20, indent: 20, color: Colors.black),
                Expanded(
                    child: Container(
                      padding: EdgeInsets.all(10),
                      margin: EdgeInsets.only(right: 20),
                      child: TextFormField(
                          controller: _textEditingController,
                          autofocus: record.value == null,
                          onChanged: (text) {
                            changeRecordValue(text);
                          },
                          validator: (value) {
                            if (value.isEmpty) {
                              return "Please enter a value".i18n;
                            }
                            var numericValue = double.tryParse(value);
                            if (numericValue == null) {
                              return "Please enter a numeric value".i18n;
                            }
                            return null;
                          },
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontSize: 32.0,
                              color: Colors.black
                          ),
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "0",
                          )
                      ),
                    )
                )
              ],
            )
        )
      ),
    );
  }

  void changeRecordValue(String text) {
    var numericValue = double.tryParse(text);
    if (numericValue != null) {
      numericValue = double.parse(numericValue.toStringAsFixed(2));
      numericValue = numericValue.abs();
      if (record.category.categoryType == CategoryType.expense) {
        // value is an expenses, needs to be negative
        numericValue = numericValue * -1;
      }
      record.value = numericValue;
    }
  }

  addRecurrentPattern() async {
    RecurrentRecordPattern recordPattern = RecurrentRecordPattern.fromRecord(record, recurrentPeriod);
    await database.addRecurrentRecordPattern(recordPattern);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  addOrUpdateRecord() async {
    if (record.id == null) {
      await database.addRecord(record);
    } else {
      await database.updateRecordById(record.id, record);
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  AppBar _getAppBar() {
    return AppBar(
        title: Text('Edit record'.i18n),
        actions: <Widget>[
          Visibility(
              visible: widget.passedRecord != null,
              child: IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete'.i18n, onPressed: () async {
                  AlertDialogBuilder deleteDialog = AlertDialogBuilder("Critical action".i18n)
                      .addSubtitle("Do you really want to delete this record?".i18n)
                      .addTrueButtonName("Yes".i18n)
                      .addFalseButtonName("No".i18n);

                  var continueDelete = await showDialog(context: context, builder: (BuildContext context) {
                    return deleteDialog.build(context);
                  });

                  if (continueDelete) {
                      await database.deleteRecordById(record.id);
                      Navigator.pop(context);
                  }
                }
              )
          ),]
    );
  }

  Widget _getForm() {
    return Container(
      margin: EdgeInsets.fromLTRB(10, 10, 10, 80),
      child: Column(
        children: [
          Form(
            key: _formKey,
            child: Container(
              child: Column(
                  children: [
                    _createAmountCard(),
                    _createCategoryCard(),
                    _createTitleCard(),
                    _createDateAndRepeatCard(),
                    _createAddNoteCard()
                  ]
              ),
            )
        )
      ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: _getAppBar(),
        resizeToAvoidBottomInset: false,
        body: SingleChildScrollView(
            child: _getForm()
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            if (_formKey.currentState.validate()) {
              if (recurrentPeriod == null) {
                await addOrUpdateRecord();
              } else {
                // a recurrent pattern is defined
                await addRecurrentPattern();
              }
            }
          },
          tooltip: 'Save'.i18n,
          child: const Icon(Icons.save),
        ),
      );
  }
}