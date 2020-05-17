
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/database-service.dart';
import 'package:piggybank/services/inmemory-database.dart';
import '../style.dart';
import './i18n/edit-movement-page.i18n.dart';

class EditMovementPage extends StatefulWidget {

  /// EditMovementPage is a page containing forms for the editing of a Movement object.
  /// EditMovementPage can take the movement object to edit as a constructor parameters
  /// or can create a new Movement otherwise.

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

  Widget _getPageSeparatorLabel(String labelText) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.all(15),
        child: Text(labelText, style: Body1Style, textAlign: TextAlign.left),
      ),
    );
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
              _getPageSeparatorLabel("Value"),
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
              _getPageSeparatorLabel("Date"),
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
                      padding: EdgeInsets.all(10),
                      child: Text(
                       movement.dateTime.toString(),
                       style: TextStyle(fontSize: 22),
                     ), 
                    ),
                    borderSide: BorderSide(color: Colors.grey, width: 1),
                  ),
                )
              ],),
              _getPageSeparatorLabel("Description"),
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
                        decoration: InputDecoration(
                            hintText: "42",
                            labelText: 'Value',
                            border: OutlineInputBorder()
                        )),
                  )
                ],
              ),
              _getPageSeparatorLabel("Labels"),
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