
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './i18n/recurrent-patterns.i18n.dart';

class ViewRecurrentPatternPage extends StatefulWidget {

  RecurrentRecordPattern? passedPattern;
  ViewRecurrentPatternPage({Key? key, this.passedPattern}) : super(key: key);

  @override
  ViewRecurrentPatternPageState createState() => ViewRecurrentPatternPageState();
}

class ViewRecurrentPatternPageState extends State<ViewRecurrentPatternPage> {

  DatabaseInterface database = ServiceConfig.database;
  TextEditingController _textEditingController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  RecurrentPeriod? recurrentPeriod;
  late String currency;

  Future<String> getCurrency() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('currency') ?? "€";
  }

  @override
  void initState() {
    super.initState();
    currency = "€";
    getCurrency().then((value) {
      setState(() {
        currency = value;
      });
    });
    recurrentPeriod = widget.passedPattern!.recurrentPeriod;
  }

  Widget _createAddNoteCard() {
    return Visibility(
      visible: widget.passedPattern!.description != null,
      child: Card(
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.only(bottom: 40.0, top: 10, right: 10, left: 10),
          child: TextFormField(
              enabled: false,
              onChanged: (text) {
                setState(() {
                  widget.passedPattern!.description = text;
                });
              },
              style: TextStyle(
                  fontSize: 22.0,
                  color: Colors.black
              ),
              initialValue: widget.passedPattern!.description,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Add a note".i18n,
              )
          ),
        ),
      ),
    );
  }

  Widget _createTitleCard() {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
        child: TextFormField(
            enabled: false,
            onChanged: (text) {
              setState(() {
                widget.passedPattern!.title = text;
              });
            },
            style: TextStyle(
                fontSize: 22.0,
                color: Colors.black
            ),
            maxLines: 1,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: EdgeInsets.all(10),
                border: InputBorder.none,
                hintText: widget.passedPattern!.category!.name,
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
                child: Row(
                  children: [
                    _createCategoryCirclePreview(40.0),
                    Container(
                      margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                      child: Text(widget.passedPattern!.category!.name!, style: TextStyle(fontSize: 20, color: Colors.blueAccent),),
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
    Category toRender = (widget.passedPattern!.category == null) ? defaultCategory : widget.passedPattern!.category!;
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
        padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
        child: Column(
          children: [
            InkWell(
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 28, color: Colors.blueAccent,),
                  Container(
                    margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                    child: Row(
                      children: [
                        Text("From:".i18n, style: TextStyle(fontSize: 20)),
                        Text(" ", style: TextStyle(fontSize: 20)),
                        Text(getDateStr(widget.passedPattern!.dateTime), style: TextStyle(fontSize: 20, color: Colors.blueAccent))
                      ],
                    ),
                  )
                ],
              ),
            ),
            Divider(),
            InkWell(
                child: Row(
                  children: [
                    Icon(Icons.repeat, size: 28, color: Colors.blueAccent,),
                    Container(
                      margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                      child: Row(
                        children: [
                          Text("Repeat:".i18n, style: TextStyle(fontSize: 20)),
                          Text(" ".i18n, style: TextStyle(fontSize: 20)),
                          Text(recurrentPeriodString(recurrentPeriod).i18n, style: TextStyle(fontSize: 20, color: Colors.blueAccent))
                        ],
                      ),
                    )
                  ],
                )
            ),
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
                          enabled: false,
                          controller: _textEditingController,
                          autofocus: widget.passedPattern!.value == null,
                          onChanged: (text) {
                            var numericValue = double.tryParse(text);
                            if (numericValue != null) {
                              numericValue = double.parse(numericValue.toStringAsFixed(2));
                              numericValue = numericValue.abs();
                              if (widget.passedPattern!.category!.categoryType == CategoryType.expense) {
                                // value is an expenses, needs to be negative
                                numericValue = numericValue * -1;
                              }
                              widget.passedPattern!.value = numericValue;
                            }
                          },
                          validator: (value) {
                            if (value!.isEmpty) {
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
                          keyboardType: TextInputType.numberWithOptions(signed: false, decimal: true),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: widget.passedPattern!.value!.toStringAsFixed(2),
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

  AppBar _getAppBar() {
    return AppBar(
        title: Text('Recurrent record detail'.i18n),
        actions: <Widget>[
          Visibility(
              visible: widget.passedPattern != null,
              child: IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete'.i18n, onPressed: () async {
                  AlertDialogBuilder deleteDialog = AlertDialogBuilder("Critical action".i18n)
                      .addSubtitle("Do you really want to delete this recurrent record?".i18n)
                      .addTrueButtonName("Yes".i18n)
                      .addFalseButtonName("No".i18n);
                  var continueDelete = await showDialog(context: context, builder: (BuildContext context) {
                    return deleteDialog.build(context);
                  });
                  if (continueDelete) {
                      await database.deleteRecurrentRecordPatternById(widget.passedPattern!.id);
                      Navigator.pop(context);
                  }
                }
              )
          ),]
    );
  }

  Widget _getForm() {
    return Container(
      margin: EdgeInsets.all(10),
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
    );
  }
}