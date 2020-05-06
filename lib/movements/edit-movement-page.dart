
import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/database-service.dart';
import 'package:piggybank/services/inmemory-database.dart';
import './i18n/edit-movement-page.i18n.dart';

class EditMovementPage extends StatefulWidget {

  Movement passedMovement;
  EditMovementPage({Key key, this.passedMovement}) : super(key: key);

  @override
  EditMovementPageState createState() => EditMovementPageState();
}

class EditMovementPageState extends State<EditMovementPage> {

  DatabaseService database = new InMemoryDatabase();

  @override
  void initState() {
    super.initState();
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
                  children: <Widget>[]
                ),
              ),
            ),
          ],
        ));
  }
}