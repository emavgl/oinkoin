
import 'package:flutter/material.dart';
import '../style.dart';
import '../i18n/edit-category-page.i18n.dart';

class EditCategoryPage extends StatefulWidget {

  @override
  EditCategoryPageState createState() => EditCategoryPageState();
}

class EditCategoryPageState extends State<EditCategoryPage> {

  List<Color> colors = [
    Colors.green[300],
    Colors.red[300],
    Colors.blue[300],
    Colors.orange[300],
    Colors.yellow[600],
    Colors.purple[200],
    Colors.grey,
    Colors.black,
  ];

  Color chosenColor;
  IconData chosenIcon;

  @override
  void initState() {
    super.initState();
    chosenColor = colors[0];
    chosenIcon = Icons.category;
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

  Widget _getSliverColors() {
    return SliverToBoxAdapter(
        child: new ConstrainedBox(
          constraints: new BoxConstraints(),
          child: Column(
            children: <Widget>[
              _getPageSeparatorLabel("Colors"),
              _buildColorList(),
            ],
          )
      )
    );
  }

  Widget _buildColorList() {
      return ListView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          itemCount: colors.length,
          itemBuilder: /*1*/ (context, index) {
            return Container(
                margin: EdgeInsets.all(10),
                child: Container(width: 70, child:
                ClipOval(
                    child: Material(
                      color: colors[index], // button color
                      child: InkWell(
                        splashColor: Colors.white30, // inkwell color
                        onTap: () {
                          setState(() {
                            chosenColor = colors[index];
                          });
                        },
                      ),
                    ))
                )
            );
      });
  }

  Widget _createColorsList() {
    return Container(
      height: 90,
      child: _buildColorList(),
    );
  }

  Widget _createCategoryCirclePreview() {
    return Container(
      margin: EdgeInsets.all(10),
      child: ClipOval(
          child: Material(
              color: chosenColor, // button color
              child: InkWell(
                splashColor: chosenColor, // inkwell color
                child: SizedBox(width: 70, height: 70,
                    child: Icon(chosenIcon, color: Colors.white, size: 30,),
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
          child: TextField(
              style: TextStyle(
                  fontSize: 22.0,
                  color: Colors.black
              ),
              decoration: InputDecoration(
                  hintText: "Category name",
                  border: OutlineInputBorder()
              )),
      ));
  }

  Widget _getAppBar() {
    return AppBar(
        title: Text('New category'.i18n),
        actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.save),
          tooltip: 'Show Snackbar', onPressed: () {},
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
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(child: _createCategoryCirclePreview()),
                    Container(child: _getTextField()),
                  ],
                ),
                _getPageSeparatorLabel("Color"),
                _createColorsList(),
              ],
            ),
          ),
        ),
      ],
    ));
  }
}