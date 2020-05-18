
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/database-service.dart';
import 'package:piggybank/services/inmemory-database.dart';
import '../style.dart';
import './i18n/edit-movement-page.i18n.dart';

class EditMovementPage extends StatefulWidget {

  Movement passedMovement;
  EditMovementPage({Key key, this.passedMovement}) : super(key: key);

  @override
  EditMovementPageState createState() => EditMovementPageState();
}

class EditMovementPageState extends State<EditMovementPage> {

  DatabaseService database = new InMemoryDatabase();
  final _formKey = GlobalKey<FormState>();
  Movement movement;

  @override
  void initState() {
    super.initState();
    movement = new Movement(null, null, null, DateTime.now());
  }

  Widget _createCategoryCirclePreview() {
    Category defaultCategory = Category("Missing", color: Category.colors[0], iconCodePoint: FontAwesomeIcons.question.codePoint);
    Category toRender = (movement.category == null) ? defaultCategory : movement.category;
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
                  onTap: () {},
                )
            )
        )
    );
  }

  Widget _getTextField() {
    return Expanded(
        child: Container(
          margin: EdgeInsets.all(10),
          child: TextFormField(
              onChanged: (text) {
                setState(() {
                  movement.description = text;
                });
              },
              initialValue: movement.description,
              style: TextStyle(
                  fontSize: 22.0,
                  color: Colors.black
              ),
              decoration: InputDecoration(
                  hintText: "Movement name  (optional)",
                  border: OutlineInputBorder()
              )),
        ));
  }

  Widget _getFormLabel(String labelText, {topMargin: 14.0}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.fromLTRB(0, topMargin, 14, 14),
        child: Text(labelText, style: Body1Style, textAlign: TextAlign.left),
      ),
    );
  }

  String _getHumanReadableDate(DateTime targetDate) {
    return new DateFormat("EEEE d.M.y").format(targetDate);
  }

  Widget _getAppBar() {
    return AppBar(
        title: Text('Edit movement'.i18n),
        actions: <Widget>[
          Visibility(
              visible: widget.passedMovement != null,
              child: IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete', onPressed: () {}
              )
          ),
          IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save', onPressed: () {}
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
              _getFormLabel("How much?"),
              Row(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.fromLTRB(12, 12, 20, 12),
                      child: Text("€", style: Body1Style, textAlign: TextAlign.left),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                        keyboardType: TextInputType.number,
                        onChanged: (text) {
                          setState(() {
                            movement.description = text;
                          });
                        },
                        initialValue: movement.description,
                        style: TextStyle(
                            fontSize: 22.0,
                            color: Colors.black
                        ),
                        decoration: InputDecoration(
                            hintText: "42",
                            labelText: 'Value',
                            border: OutlineInputBorder()
                        )),
                  )
                ],
              ),
              _getFormLabel("When?", topMargin: 30.0),
              Row(children: <Widget>[
                Expanded(
                  child: OutlineButton(
                    onPressed: () async {
                      DateTime result = await showDatePicker(context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(1970), lastDate: DateTime(2050));
                      if (result != null) {
                        setState(() {
                          movement.dateTime = result;
                        });
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                        _getHumanReadableDate(movement.dateTime),
                        style: TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                    borderSide: BorderSide(color: Colors.grey, width: 0),
                  ))
              ],),
              _getFormLabel("How?", topMargin: 30.0),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                        onChanged: (text) {
                          setState(() {
                            movement.description = text;
                          });
                        },
                        initialValue: movement.description,
                        style: TextStyle(
                            fontSize: 22.0,
                            color: Colors.black
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder()
                        )),
                  )
                ],
              ),
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
                        Container(child: _getTextField()),
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