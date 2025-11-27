import 'package:flutter/material.dart';

class AggregatedListView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  const AggregatedListView({
    Key? key,
    required this.items,
    required this.itemBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      separatorBuilder: (context, index) {
        return Divider();
      },
      padding: const EdgeInsets.all(6.0),
      itemBuilder: (context, i) {
        return itemBuilder(context, items[i], i);
      },
    );
  }
}
