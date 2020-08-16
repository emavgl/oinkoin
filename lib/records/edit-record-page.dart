
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/categories/categories-tab-page-view.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../style.dart';
import './i18n/edit-record-page.i18n.dart';

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
  final _formKey = GlobalKey<FormState>();
  Record record;

  Record passedRecord;
  Category passedCategory;
  String currency;

  EditRecordPageState(this.passedRecord, this.passedCategory);

  Future<String> getCurrency() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('currency') ?? "€";
  }

  @override
  void initState() {
    super.initState();
    currency = "€";
    if (passedRecord != null) {
      record = passedRecord;
    } else {
      record = new Record(null, null, passedCategory, DateTime.now());
    }
    getCurrency().then((value) {
      setState(() {
        currency = value;
      });
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
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Add a note",
              )
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
            onChanged: (text) {
              setState(() {
                record.description = text;
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
                hintText: record.category.name,
                labelText: "Record title (optional)"
            )
        ),
      ),
    );
  }

  Widget _createDateCard() {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            InkWell(
              onTap: () async {
                DateTime now = DateTime.now();
                DateTime result = await showDatePicker(context: context,
                    initialDate: now,
                    firstDate: DateTime(1970), lastDate: DateTime(2050));
                if (result != null) {
                  setState(() {
                    record.dateTime = result;
                  });
                }
              },
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 28, color: Colors.blueAccent,),
                  Container(
                    margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                    child: Text(getDateStr(record.dateTime), style: TextStyle(fontSize: 20, color: Colors.blueAccent),),
                  )
                ],
              ),
            ),
            Divider(indent: 40, thickness: 2,),
            InkWell(
              child: Row(
                children: [
                  Icon(Icons.repeat, size: 28, color: Colors.black54,),
                  Container(
                    margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                    child: Text("Repeat", style: TextStyle(fontSize: 20, color: Colors.black54),),
                  )
                ],
              ),
            ),
          ],
        )
      ),
    );
  }

  Widget _createCategoryCirclePreview() {
    Category defaultCategory = Category("Missing".i18n, color: Category.colors[0], iconCodePoint: FontAwesomeIcons.question.codePoint);
    Category toRender = (record.category == null) ? defaultCategory : record.category;
    return Container(
        margin: EdgeInsets.all(10),
        child: ClipOval(
            child: Material(
                color: toRender.color, // button color
                child: InkWell(
                  splashColor: toRender.color, // inkwell color
                  child: SizedBox(width: 70, height: 70,
                    child: Icon(toRender.icon, color: Colors.white, size: 30,),
                  ),
                  onTap: () async {
                    var selectedCategory = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CategoryTabPageView()),
                    );
                    if (selectedCategory != null) {
                      setState(() {
                        record.category = selectedCategory;
                      });
                    }
                  },
                )
            )
        )
    );
  }

  Widget _createAmountCard() {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(12, 12, 20, 12),
            child: Text(currency, style: Body1Style, textAlign: TextAlign.left),
          ),
          Expanded(
              child: TextFormField(
                  onChanged: (text) {
                    setState(() {
                      record.description = text;
                    });
                  },
                  style: TextStyle(
                      fontSize: 50.0,
                      color: Colors.black
                  ),
                  keyboardType: TextInputType.numberWithOptions(signed: false, decimal: true),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "42.00",
                  )
              ),
          )
        ],
      )
    );
  }

  saveRecord() async {
    if (record.id == null) {
      await database.addRecord(record);
    } else {
      await database.updateRecordById(record.id, record);
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _getAppBar() {
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
          ),
          IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save'.i18n, onPressed: () async {
                if (_formKey.currentState.validate()) {
                  await saveRecord();
                }
              }
          )]
    );
  }

  Widget _getForm() {
    return Form(
      key: _formKey,
      child: Container(
        margin: EdgeInsets.all(10),
        child:  Column(
            children: [
              _createTitleCard(),
              _createDateCard(),
              _createAddNoteCard()
            ]
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        type: MaterialType.transparency,
        child: Column(
          children: <Widget>[
            _getAppBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(child: _createCategoryCirclePreview()),
                        Expanded(
                          child:  Container(child: _createAmountCard()),
                        ),
                      ],
                    ),
                    _getForm(),
                  ]
                ),
              ),
            ),
          ],
        ));
  }
}