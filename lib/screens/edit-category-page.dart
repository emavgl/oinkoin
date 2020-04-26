
import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/services/movements-in-memory-database.dart';
import '../style.dart';
import '../i18n/edit-category-page.i18n.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

  List<IconData> icons = [
    // food
    FontAwesomeIcons.hamburger,
    FontAwesomeIcons.pizzaSlice,
    FontAwesomeIcons.cheese,
    FontAwesomeIcons.appleAlt,
    FontAwesomeIcons.breadSlice,
    FontAwesomeIcons.iceCream,
    FontAwesomeIcons.cocktail,
    FontAwesomeIcons.wineGlass,
    FontAwesomeIcons.birthdayCake,
    FontAwesomeIcons.fish,
    FontAwesomeIcons.coffee,

    // transports
    FontAwesomeIcons.gasPump,
    FontAwesomeIcons.car,
    FontAwesomeIcons.carBattery,
    FontAwesomeIcons.parking,
    FontAwesomeIcons.biking,
    FontAwesomeIcons.motorcycle,
    FontAwesomeIcons.bicycle,
    FontAwesomeIcons.caravan,
    FontAwesomeIcons.taxi,
    FontAwesomeIcons.planeDeparture,
    FontAwesomeIcons.ship,
    FontAwesomeIcons.train,

    // Shopping
    FontAwesomeIcons.shoppingCart,
    FontAwesomeIcons.shoppingBag,
    FontAwesomeIcons.shoppingBasket,
    FontAwesomeIcons.gem,
    FontAwesomeIcons.tag,
    FontAwesomeIcons.gift,
    FontAwesomeIcons.mitten,
    FontAwesomeIcons.socks,
    FontAwesomeIcons.hatCowboy,

    // Entertainment
    FontAwesomeIcons.gamepad,
    FontAwesomeIcons.theaterMasks,
    FontAwesomeIcons.swimmer,
    FontAwesomeIcons.bowlingBall,
    FontAwesomeIcons.golfBall,
    FontAwesomeIcons.baseballBall,
    FontAwesomeIcons.basketballBall,
    FontAwesomeIcons.footballBall,
    FontAwesomeIcons.volleyballBall,
    FontAwesomeIcons.skiing,
    FontAwesomeIcons.tv,
    FontAwesomeIcons.film,
  ];

  Color chosenColor;
  int chosenColorIndex;

  IconData chosenIcon;
  int chosenIconIndex;
  String categoryName;

  @override
  void initState() {
    super.initState();
    chosenColor = colors[0];
    chosenIcon = FontAwesomeIcons.hamburger;
    chosenIconIndex = 0;
    chosenColorIndex = 0;
    categoryName = null;
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


  Widget _getIconsGrid() {
    return GridView.count(
      // Create a grid with 2 columns. If you change the scrollDirection to
      // horizontal, this produces 2 rows
      crossAxisCount: 5,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      // Generate 100 widgets that display their index in the List.
      children: List.generate(icons.length, (index) {
        return Container(
            child: IconButton(
              // Use the FaIcon Widget + FontAwesomeIcons class for the IconData
                icon: FaIcon(icons[index]),
                color: ((chosenIconIndex == index) ? Colors.blueAccent : Colors.black45),
                onPressed: () {
                  setState(() {
                    chosenIcon = icons[index];
                    chosenIconIndex = index;
                });
                }
            )
        );
      }),
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
                        child: (index == chosenColorIndex) ? SizedBox(width: 50, height: 50,
                          child: Icon(Icons.check, color: Colors.white, size: 20,),
                        ) : Container(),
                        onTap: () {
                          setState(() {
                            chosenColor = colors[index];
                            chosenColorIndex = index;
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
              onChanged: (text) {
                categoryName = text;
              },
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
          tooltip: 'Save', onPressed: () {
            if (categoryName != null) {
              Category newCategory = new Category(categoryName, color: chosenColor);
              MovementsInMemoryDatabase.categories.add(newCategory);
              Navigator.pop(context);
            }
          },
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
                _getPageSeparatorLabel("Icons"),
                _getIconsGrid()
              ],
            ),
          ),
        ),
      ],
    ));
  }
}