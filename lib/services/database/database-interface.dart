import 'dart:async';

import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/profile.dart';
import 'package:piggybank/models/record-tag-association.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/models/wallet.dart';

abstract class DatabaseInterface {
  /// DatabaseInterface is an interface that the database classes
  /// must implement. It contains basic CRUD methods for categories and records

  /// Category CRUD
  Future<List<Category?>> getAllCategories();
  Future<List<Category?>> getCategoriesByType(CategoryType categoryType);
  Future<Category?> getCategory(String categoryName, CategoryType categoryType);
  Future<int> addCategory(Category? category);
  Future<int> updateCategory(String? existingCategoryName,
      CategoryType? existingCategoryType, Category? updatedCategory);
  Future<void> deleteCategory(String? name, CategoryType? categoryType);
  Future<void> archiveCategory(
      String categoryName, CategoryType categoryType, bool isArchived);
  Future<void> resetCategoryOrderIndexes(List<Category> orderedCategories);

  /// Record CRUD
  Future<Record?> getRecordById(int id);
  Future<void> deleteRecordById(int? id);
  Future<void> deleteRecordsInBatch(List<int> ids);
  Future<int> addRecord(Record? record);
  Future<void> addRecordsInBatch(List<Record?> records);
  Future<int?> updateRecordById(int? recordId, Record? newRecord);
  Future<void> updateRecordWalletInBatch(List<int> ids, int? walletId);
  Future<void> duplicateRecordsInBatch(List<int> ids);
  Future<DateTime?> getDateTimeFirstRecord();
  Future<List<Record?>> getAllRecords({int? profileId});
  Future<List<Record?>> getAllRecordsInInterval(DateTime? from, DateTime? to,
      {int? profileId});
  Future<Record?> getMatchingRecord(Record? record);
  Future<void> deleteFutureRecordsByPatternId(
      String recurrentPatternId, DateTime startingTime);
  Future<List<String>> suggestedRecordTitles(
      String search, String categoryName);
  Future<List<String>> getTagsForRecord(int recordId);
  Future<Set<String>> getAllTags();
  Future<Set<String>> getRecentlyUsedTags();
  Future<Set<String>> getMostUsedTagsForCategory(
      String categoryName, CategoryType categoryType);
  Future<List<Map<String, dynamic>>> getAggregatedRecordsByTagInInterval(
      DateTime? from, DateTime? to);

  // New methods for record tag associations
  Future<List<RecordTagAssociation>> getAllRecordTagAssociations();
  Future<void> renameTag(String old, String newTag);
  Future<void> deleteTag(String tagToDelete);

  // Recurrent Records Patterns CRUD
  Future<List<RecurrentRecordPattern>> getRecurrentRecordPatterns(
      {int? profileId});
  Future<RecurrentRecordPattern?> getRecurrentRecordPattern(
      String? recurrentPatternId);
  Future<void> addRecurrentRecordPattern(RecurrentRecordPattern recordPattern);
  Future<void> deleteRecurrentRecordPatternById(String? recurrentPatternId);
  Future<void> updateRecordPatternById(
      String? recurrentPatternId, RecurrentRecordPattern pattern);

  // Wallet CRUD

  /// Returns all wallets ordered by [Wallet.sortOrder], including archived ones.
  /// When [profileId] is provided, only wallets for that profile are returned.
  Future<List<Wallet>> getAllWallets({int? profileId});

  // Profile CRUD
  Future<List<Profile>> getAllProfiles();
  Future<Profile?> getDefaultProfile();
  Future<void> setDefaultProfile(int id);
  Future<Profile?> getProfileById(int id);
  Future<int> addProfile(Profile profile);
  Future<void> updateProfile(Profile profile);
  Future<void> deleteProfileAndRecords(int id);

  /// Returns the wallet with [id], or null if not found.
  Future<Wallet?> getWalletById(int id);

  /// Returns the wallet with [name] for [profileId], or null if not found.
  Future<Wallet?> getWalletByName(String name, int? profileId);

  /// Inserts [wallet] and returns its new database ID.
  Future<int> addWallet(Wallet wallet);

  /// Replaces the stored fields of wallet [id] with [wallet].
  Future<void> updateWallet(int id, Wallet wallet);

  /// Deletes wallet [id] along with all its records and recurrent patterns.
  /// Also deletes the partner side of any transfer that referenced this wallet
  /// in other wallets, since a one-sided transfer is meaningless.
  /// If this was the default wallet, another wallet is promoted to default.
  Future<void> deleteWalletAndRecords(int id);

  /// Moves all records and recurrent patterns from wallet [fromId] to [toId].
  /// Transfers between the two wallets are deleted (they would become self-referential).
  /// Transfer references in third wallets are updated to point to [toId].
  Future<void> moveRecordsToWallet(int fromId, int toId);

  /// Sets [isArchived] on wallet [id]. When archiving the default wallet,
  /// another active wallet is promoted to default automatically.
  Future<void> archiveWallet(int id, bool isArchived);

  /// Makes wallet [id] the sole default wallet.
  Future<void> setDefaultWallet(int id);

  /// Sets wallet [id] as the predefined wallet for new records.
  /// The predefined wallet can be changed by users; unlike the system
  /// default wallet, it can be deleted.
  Future<void> setPredefinedWallet(int id);

  /// Returns the current predefined wallet for new records.
  Future<Wallet?> getPredefinedWallet();

  /// Returns the current default wallet with its computed balance, or null.
  Future<Wallet?> getDefaultWallet();

  /// Persists the [sortOrder] of each wallet according to [ordered]'s position.
  Future<void> resetWalletOrderIndexes(List<Wallet> ordered);

  // Utils
  Future<void> deleteDatabase();
}
