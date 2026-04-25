import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/category-icons.dart';
import 'package:piggybank/models/model.dart';

import '../helpers/color-utils.dart';
import 'category.dart';

class Wallet extends Model {
  /// Object representing a Wallet (account).
  /// A wallet has a name, optional icon and color, and tracks balance.
  /// Balance is computed as SUM(associated records) + initialAmount.
  /// initialAmount is a hidden correction field that lets users set an
  /// arbitrary starting balance without creating fake records.

  int? id;
  String name;
  Color? color;
  int? iconCodePoint;
  IconData? icon;
  String? iconEmoji;
  double initialAmount;
  bool isArchived;
  bool isDefault; // System Default Wallet - cannot be deleted
  bool isPredefined; // User-selected default for new records
  int sortOrder;
  double? balance; // computed, not stored in DB
  String? currency; // ISO 4217 code, e.g. "USD", optional
  int? profileId;

  Wallet(
    this.name, {
    this.id,
    this.color,
    this.iconCodePoint,
    this.iconEmoji,
    this.initialAmount = 0.0,
    this.isArchived = false,
    this.isDefault = false,
    this.isPredefined = false,
    this.sortOrder = 0,
    this.balance,
    this.currency,
    this.profileId,
  }) {
    var categoryIcons = CategoryIcons.pro_category_icons;
    if (iconEmoji == null) {
      if (iconCodePoint == null ||
          categoryIcons.where((i) => i.codePoint == iconCodePoint).isEmpty) {
        icon = FontAwesomeIcons.wallet;
        iconCodePoint = icon!.codePoint;
      } else {
        icon = categoryIcons.where((i) => i.codePoint == iconCodePoint).first;
      }
    }
  }

  /// Reuse Category's color palette
  static List<Color?> get colors => Category.colors;

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'name': name,
      'color': null,
      'icon': iconEmoji == null ? (icon?.codePoint ?? iconCodePoint) : null,
      'icon_emoji': iconEmoji,
      'initial_amount': initialAmount,
      'is_archived': isArchived ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
      'is_predefined': isPredefined ? 1 : 0,
      'sort_order': sortOrder,
      'currency': currency,
      'profile_id': profileId,
    };
    if (color != null) {
      map['color'] = serializeColorToString(color!);
    }
    return map;
  }

  static Wallet fromMap(Map<String, dynamic> map) {
    final serializedColor = map['color'] as String?;
    final isDefault =
        map['is_default'] != null ? (map['is_default'] as int) == 1 : false;
    final isPredefined = map['is_predefined'] != null
        ? (map['is_predefined'] as int) == 1
        : false;
    Color? color;
    if (serializedColor != null) {
      final parts = serializedColor.split(':').map(int.parse).toList();
      color = Color.fromARGB(parts[0], parts[1], parts[2], parts[3]);
    } else if (isDefault) {
      color = Colors.green[300];
    }

    final isArchived =
        map['is_archived'] != null ? (map['is_archived'] as int) == 1 : false;
    final sortOrder = (map['sort_order'] as int?) ?? 0;
    final initialAmount = (map['initial_amount'] as num?)?.toDouble() ?? 0.0;
    // balance is a computed column returned by SQL queries, not stored directly
    final balance = (map['balance'] as num?)?.toDouble();

    return Wallet(
      map['name'] as String,
      id: map['id'] as int?,
      color: color,
      iconCodePoint: map['icon'] as int?,
      iconEmoji: map['icon_emoji'] as String?,
      initialAmount: initialAmount,
      isArchived: isArchived,
      isDefault: isDefault,
      isPredefined: isPredefined,
      sortOrder: sortOrder,
      balance: balance,
      currency: map['currency'] as String?,
      profileId: map['profile_id'] as int?,
    );
  }
}
